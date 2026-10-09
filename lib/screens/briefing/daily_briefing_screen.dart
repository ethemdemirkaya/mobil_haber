import 'package:pusula_news/core/theme/app_icons.dart';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/ai/openrouter_client.dart';
import '../../core/tts/briefing_audio_handler.dart';
import '../../core/tts/briefing_player.dart';
import '../../core/tts/tts_engine_factory.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/repositories/daily_briefing_service.dart';
import '../../data/repositories/market_widget_service.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/tts_settings_provider.dart';
import '../../widgets/market_mini_widget.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/weather_location_screen.dart';

part 'widgets/briefing_player_bar.dart';
part 'widgets/briefing_widgets.dart';

/// Bugünün haberlerinden AI ile yazılmış sesli brifingi okutan ekran.
///
/// Üç ana parça:
///   1. Üst kategori şeridi: "Genel" + uygulamada haberi olan kategoriler
///      (Spor, Ekonomi, Teknoloji vb). Tıklandığında o konuya odaklı
///      brifing üretilir, in-memory cache ile geri dönüşler hızlı.
///   2. Orta gövde: AI'ın hazırladığı brifing metni; konuşulan cümle
///      vurgulanır.
///   3. Alt player bar: play/pause/stop/restart + hız sürgüsü +
///      ilerleme çubuğu.
///
/// TTS init "best-effort": her metot ayrı try/catch sarmalı; bir tanesi
/// `MissingPluginException` fırlatsa bile diğerleri çalışmaya devam eder.
/// Hot reload ile native plugin kaydolmadığında da ekran çökmek yerine
/// kullanıcıya net bir mesaj verir.
class DailyBriefingScreen extends StatefulWidget {
  const DailyBriefingScreen({super.key});

  @override
  State<DailyBriefingScreen> createState() => _DailyBriefingScreenState();
}

class _DailyBriefingScreenState extends State<DailyBriefingScreen> {
  final FlutterTts _tts = FlutterTts();
  final DailyBriefingService _service = DailyBriefingService();
  late final TtsEngineFactory _engines =
      TtsEngineFactory(systemTts: _tts, player: _audioPlayer);
  final MarketWidgetService _marketService = MarketWidgetService();
  StreamSubscription<BriefingLockAction>? _lockActionSub;
  MarketSnapshot? _market;

  /// Cümleleri sırayla çalan oynatıcı — hız, ileri sarma ve duraklatma
  /// mantığı burada değil, [BriefingPlayer]'da (birim testli).
  final BriefingPlayer _player = BriefingPlayer();

  /// Oynatıcıya verilen motorun ayar imzası; ayarlar değişince motor
  /// yeniden kurulur.
  String? _engineKey;

  /// Lock-screen kontrolü için audio_service handler'ı varsa onun
  /// player'ını kullanırız (notification'a state yansır); yoksa local
  /// player. Hem mobile hem desktop'ta çalışır.
  AudioPlayer get _audioPlayer => BriefingAudioHandler.isBooted
      ? BriefingAudioHandler.instance.player
      : _localAudioPlayer;
  final AudioPlayer _localAudioPlayer = AudioPlayer();

  // Akış durumu — başlangıçta brifing üretiliyor → spinner gösterilsin.
  bool _generating = true;
  String? _briefing;
  String? _error;
  String? _ttsWarning; // TTS init uyarısı (Türkçe ses yok / desteklenmiyor)

  // TTS state
  bool _ttsReady = false;
  bool _ttsSupported = true; // false → bu platformda hiç çalıştırılamaz

  // ─── Uyku zamanlayıcısı ───
  // Belirlenen sürenin sonunda playback otomatik durur. UI dropdown'unda
  // "Kapalı / 15 / 30 / 60 dk" seçilebilir; null = kapalı.
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndsAt;

  // Kategori state + cache (in-memory; ekran kapanınca temizlenir).
  late BriefingTopic _topic;
  final Map<String, _CachedBriefing> _cache = <String, _CachedBriefing>{};

  /// Kategori şeridinde gösterilecek konular: "Genel" + uygulamada bu an
  /// haberi olan kategoriler. NewsCategory.values sırasını korur.
  List<BriefingTopic> _availableTopics(NewsProvider news) {
    final topics = <BriefingTopic>[const BriefingTopic()]; // Genel
    for (final c in NewsCategory.values) {
      if (c.id == NewsCategory.all.id) continue;
      // O kategoride en az 1 makale varsa ekle.
      final hasAny = news.articlesOf(c.id).isNotEmpty;
      if (hasAny) topics.add(BriefingTopic(category: c));
    }
    return topics;
  }

  @override
  void initState() {
    super.initState();
    _topic = const BriefingTopic(); // Genel
    _player.addListener(_onPlayerChanged);
    _bootstrap();
    _wireLockScreenActions();
  }

  /// Lock screen / bildirim panel butonlarını dinle. Kullanıcı oradan
  /// play/pause/stop/next/prev'e basınca bizim screen state'inde
  /// tetikle.
  void _wireLockScreenActions() {
    if (!BriefingAudioHandler.isBooted) return;
    _lockActionSub = BriefingAudioHandler.instance.actions.listen((action) {
      if (!mounted) return;
      // Eskiden ileri/geri önce durdurup (indeks 0) sonra çalıyordu —
      // kilit ekranındaki "sonraki cümle" başa sarıyordu.
      switch (action) {
        case BriefingLockAction.play:
          _player.play();
        case BriefingLockAction.pause:
          _player.pause();
        case BriefingLockAction.stop:
          _player.stop();
        case BriefingLockAction.skipNext:
          _player.skipNext();
        case BriefingLockAction.skipPrev:
          _player.skipPrevious();
      }
    });
  }

  /// Oynatıcı durumu değişince ekranı ve (varsa) hata uyarısını güncelle.
  void _onPlayerChanged() {
    if (!mounted) return;
    final err = _player.error;
    setState(() {
      if (err is MissingPluginException) {
        _ttsSupported = false;
        _ttsWarning = 'Sesli okuma motoru bu cihazda kullanılamıyor. '
            'Uygulamayı tamamen kapatıp yeniden açın (hot reload yetmez).';
      } else if (err != null) {
        _ttsWarning = 'Sesli okuma sırasında hata: $err';
      }
    });
  }

  Future<void> _bootstrap() async {
    // ÖNEMLİ: AiSettingsProvider async _load() ile başlatılıyor; biz
    // _generate'i ondan önce çağırırsak `_enabled = false` (default)
    // okur ve "yapılandırılmamış" hatası verir. Provider initialized
    // olana kadar bekle.
    await _waitForAiInit();
    if (!mounted) return;

    // TTS init + AI generate + market widget paralel başlasın.
    final ttsFuture = _initTts();
    final genFuture = _generate();
    final marketFuture = _loadMarket();
    await Future.wait([ttsFuture, genFuture, marketFuture]);
    if (!mounted) return;
    final canPlay =
        _ttsReady ||
        _activeEngine == TtsEngineKind.openai ||
        _activeEngine == TtsEngineKind.elevenlabs ||
        _activeEngine == TtsEngineKind.edge;
    if (_briefing != null && _briefing!.isNotEmpty && canPlay) {
      _ensureEngine();
      await _player.play();
    }
  }

  /// AiSettingsProvider'ın SharedPreferences'dan _load() tamamlamasını
  /// bekle. Polling yerine provider'ın `whenInitialized` Completer'ına
  /// abone oluyoruz — pil/CPU israfı yok. Provider takılırsa 2 sn'lik
  /// timeout splash'a sıkışmamızı engeller.
  Future<void> _waitForAiInit() async {
    final ai = context.read<AiSettingsProvider>();
    if (ai.initialized) return;
    try {
      await ai.whenInitialized.timeout(const Duration(milliseconds: 2000));
    } on TimeoutException {
      debugPrint('[Pusula][Briefing] AI init timeout — devam ediliyor');
    }
  }

  /// AI ready değilken net açıklama: hangi durumda olduğunu tespit edip
  /// kullanıcının ne yapması gerektiğini söyler.
  String _diagnoseAiNotReady(AiSettingsProvider ai) {
    if (!ai.initialized) {
      return 'Ayarlar yükleniyor… Bir saniye sonra tekrar deneyin.';
    }
    if (!ai.enabled) {
      return 'Yapay zeka kapalı. Ayarlar > Yapay Zeka Özetleme'
          ' bölümünden açın.';
    }
    if (ai.modelId.isEmpty) {
      return 'Model seçilmedi. Ayarlar > Yapay Zeka > Model bölümünden '
          'bir model seçin.';
    }
    // Mode'a göre net mesaj.
    if (ai.apiKeyMode == ApiKeyMode.userProvided && !ai.hasUserApiKey) {
      return 'Aktif mod: "Kendi anahtarım" — fakat anahtar girilmemiş.\n'
          'Ayarlar > Yapay Zeka > Aktif Anahtar bölümünde OpenRouter '
          'anahtarınızı yapıştırın veya "Varsayılan" moduna geçin.';
    }
    if (ai.apiKeyMode == ApiKeyMode.builtIn && !ai.hasBuiltInKey) {
      return 'Aktif mod: "Varsayılan" — ama bu APK varsayılan anahtarsız '
          'derlenmiş. Ayarlar > Yapay Zeka > "Kendi anahtarım" moduna '
          'geçip OpenRouter anahtarınızı girin.';
    }
    return 'Yapay zeka yapılandırması eksik. Ayarlar > Yapay Zeka\'yı '
        'kontrol edin.';
  }

  Future<void> _loadMarket() async {
    try {
      final prefs = context.read<PreferencesProvider>();
      final snap = await _marketService.fetch(
        lat: prefs.weatherLat,
        lon: prefs.weatherLon,
        city: prefs.weatherCityName,
      );
      if (!mounted) return;
      setState(() => _market = snap);
    } catch (e) {
      debugPrint('[Pusula][Market] yüklenemedi: $e');
    }
  }

  // ─────────────── TTS ───────────────

  /// Resilient TTS init. Her metodu ayrı try/catch ile sarıyoruz çünkü:
  ///  - `MissingPluginException`: pubspec güncellendi ama hot reload sonrası
  ///    native registrar yenilenmedi → tam restart şart.
  ///  - Bazı metodlar belirli platformlarda (Windows, Linux, Web) implement
  ///    edilmemiş — birinin patlaması diğerlerini kırmasın.
  Future<void> _initTts() async {
    // iOS shared instance + audio session (opsiyonel).
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _safeCall(
        'setSharedInstance',
        () async => _tts.setSharedInstance(true),
      );
      await _safeCall(
        'setIosAudioCategory',
        () async => _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        ),
      );
    }

    // Türkçe dil kontrolü — bazı platformlarda hiç implement edilmemiş.
    // Sonuç ne olursa olsun setLanguage'i deniyoruz; çoğu cihazda
    // setLanguage başarılı olur, sadece bu kontrol fonksiyonu eksik.
    bool? langOk;
    final supported = await _safeCallReturning<dynamic>(
      'isLanguageAvailable',
      () => _tts.isLanguageAvailable('tr-TR'),
    );
    if (supported is bool) langOk = supported;

    final setLangOk = await _safeCall(
      'setLanguage',
      () async => _tts.setLanguage('tr-TR'),
    );

    if (langOk == false || (setLangOk == false && langOk == null)) {
      _ttsWarning =
          'Cihazınızda Türkçe TTS sesi yüklü olmayabilir. '
          'Sistem ayarları > Erişilebilirlik > Konuşma Sentezi\'nden '
          'Türkçe ses paketini yüklemeyi deneyin.';
    }

    await _safeCall('setVolume', () async => _tts.setVolume(1.0));
    await _safeCall(
      'awaitSpeakCompletion',
      () async => _tts.awaitSpeakCompletion(false),
    );

    _ttsReady = true;
    if (mounted) {
      _ensureEngine(force: true);
      setState(() {});
    }
  }

  /// Tek bir TTS metodunu güvenli çağırır; başarı (true/false) döner.
  /// `MissingPluginException` ya da PlatformException sessizce yutulur,
  /// debugPrint'e log düşer.
  Future<bool> _safeCall(String name, Future<dynamic> Function() op) async {
    try {
      await op();
      return true;
    } on MissingPluginException catch (e) {
      debugPrint('[Pusula][TTS] $name: MissingPluginException → $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint(
        '[Pusula][TTS] $name: PlatformException → ${e.code} ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('[Pusula][TTS] $name: $e');
      return false;
    }
  }

  /// `_safeCall` gibi ama dönüş değeri ile.
  Future<T?> _safeCallReturning<T>(
    String name,
    Future<T?> Function() op,
  ) async {
    try {
      return await op();
    } on MissingPluginException catch (e) {
      debugPrint('[Pusula][TTS] $name: MissingPluginException → $e');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[Pusula][TTS] $name: PlatformException → ${e.code}');
      return null;
    } catch (e) {
      debugPrint('[Pusula][TTS] $name: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _player.dispose();
    _lockActionSub?.cancel();
    _sleepTimer?.cancel();
    _localAudioPlayer.dispose();
    _engines.close();
    super.dispose();
  }

  /// Uyku zamanlayıcısını ayarlar. null = iptal et.
  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      setState(() {
        _sleepTimer = null;
        _sleepDuration = null;
        _sleepEndsAt = null;
      });
      return;
    }
    setState(() {
      _sleepDuration = duration;
      _sleepEndsAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () async {
        if (!mounted) return;
        await _player.stop();
        if (!mounted) return;
        setState(() {
          _sleepTimer = null;
          _sleepDuration = null;
          _sleepEndsAt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uyku zamanlayıcısı sona erdi.'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    });
  }

  /// Ayarlardan seçili motor — UI build sırasında okunup playback'te
  /// kullanılır. AI ayarları ekranından değiştirildiğinde Consumer
  /// otomatik rebuild eder.
  TtsEngineKind get _activeEngine =>
      context.read<TtsSettingsProvider>().ttsEngine;

  // ─────────────── AI generation ───────────────

  /// Seçili kategori için brifing üretir. Cache'te varsa onu yükler;
  /// yoksa OpenRouter çağrısı yapar.
  Future<void> _generate({bool forceRefresh = false}) async {
    final ai = context.read<AiSettingsProvider>();
    if (!ai.isReady()) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = _diagnoseAiNotReady(ai);
      });
      return;
    }

    final news = context.read<NewsProvider>();
    final articles = _filterArticles(news);
    if (articles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = _topic.isGeneral
            ? 'Henüz haber yüklenmedi. Ana sayfada birkaç saniye '
                  'bekleyip tekrar deneyin.'
            : '${_topic.displayName} kapsamında henüz haber bulunamadı. '
                  'Bu kategoriden bir kaynak seçtiğinden emin ol.';
      });
      return;
    }

    // Cache hit?
    if (!forceRefresh) {
      final cached = _cache[_topic.cacheKey];
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _briefing = cached.text;
          _generating = false;
          _error = null;
        });
        await _player.load(cached.utterances);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _generating = true;
      _error = null;
      _briefing = null;
    });
    await _player.load(const []);

    try {
      // Brifing girişine hava + döviz cümlesini AI'a aktar — spiker
      // doğal şekilde "Hava 18 derece, dolar 38 lira" diyerek girsin.
      final intro = _market?.toSpokenIntro();
      var userPrompt = _service.buildUserPrompt(
        articles: articles,
        now: DateTime.now(),
        topic: _topic,
      );
      if (intro != null) {
        userPrompt =
            'Brifing girişinde şu bağlamı doğal bir şekilde kullan: '
            '"$intro"\n\n$userPrompt';
      }
      final raw = await ai.generate(
        systemPrompt: DailyBriefingService.systemPromptFor(_topic),
        userPrompt: userPrompt,
        // Akıl yürüten modeller yanıttan önce token harcıyor; 700'de
        // brifing yarıda kesilebiliyordu.
        maxTokens: 1500,
        // Haber metni: yaratıcılık değil sadakat.
        temperature: 0.3,
      );
      final cleaned = _service.sanitizeForSpeech(raw);
      if (cleaned.isEmpty) {
        throw const OpenRouterException(
          'Model boş yanıt döndü — farklı bir model deneyin.',
        );
      }
      final parts = _service.splitIntoUtterances(cleaned);
      _cache[_topic.cacheKey] = _CachedBriefing(cleaned, parts);
      if (!mounted) return;
      setState(() {
        _briefing = cleaned;
        _generating = false;
      });
      await _player.load(parts);
      // Lock screen "Now Playing" başlığını set et.
      if (BriefingAudioHandler.isBooted) {
        // ignore: unawaited_futures
        BriefingAudioHandler.instance.setBriefingItem(
          title: _topic.displayName,
          artist: 'Pusula • ${parts.length} cümle',
        );
      }
    } on OpenRouterException catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Beklenmeyen hata: $e';
      });
    }
  }

  List<Article> _filterArticles(NewsProvider news) {
    if (_topic.isGeneral) {
      return DailyBriefingService.selectArticles(
        trending: news.trending(take: 4),
        latest: news.latest(take: 80),
      );
    }
    final catId = _topic.category!.id;
    final inCategory = List<Article>.of(news.articlesOf(catId))
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return DailyBriefingService.selectArticles(
      trending:
          news.trending(take: 10).where((a) => a.categoryId == catId).toList(),
      latest: inCategory,
    );
  }

  // ─────────────── Playback ───────────────

  /// Seçili TTS ayarlarına göre motoru kurar; ayarlar değişmediyse
  /// dokunmaz. Bulut motoru hata verirse cihaz sesine geçilir.
  void _ensureEngine({bool force = false}) {
    final tts = context.read<TtsSettingsProvider>();
    final key = TtsEngineFactory.keyFor(tts);
    if (!force && key == _engineKey) return;
    _engineKey = key;
    final kind = tts.ttsEngine;
    _player.setEngine(_engines.build(
      tts,
      onFallback: (e) {
        if (!mounted) return;
        setState(() {
          _ttsWarning = '${kind.label} şu an kullanılamıyor '
              '(${TtsEngineFactory.shortError(e)}). Cihazın sesiyle devam '
              'ediliyor.';
        });
      },
    ));
  }

  Future<void> _restart() async {
    await _player.stop();
    await _player.play();
  }

  Future<void> _selectTopic(BriefingTopic t) async {
    if (t.cacheKey == _topic.cacheKey) return;
    HapticFeedback.selectionClick();
    await _player.stop();
    setState(() {
      _topic = t;
      _error = null;
    });
    await _generate();
    if (!mounted) return;
    final canPlayAfterSelect =
        _ttsReady ||
        _activeEngine == TtsEngineKind.openai ||
        _activeEngine == TtsEngineKind.elevenlabs ||
        _activeEngine == TtsEngineKind.edge;
    if (_briefing != null && canPlayAfterSelect) await _player.play();
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await _player.stop();
    await _generate(forceRefresh: true);
    if (!mounted) return;
    final canPlayAfterRefresh =
        _ttsReady ||
        _activeEngine == TtsEngineKind.openai ||
        _activeEngine == TtsEngineKind.elevenlabs ||
        _activeEngine == TtsEngineKind.edge;
    if (_briefing != null && canPlayAfterRefresh) await _player.play();
  }

  // ─────────────── Build ───────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final news = context.watch<NewsProvider>();
    // AI provider'ı watch ile dinle — kullanıcı Settings'te mode/key
    // değiştirince ekran anında yeniden render olsun.
    final ai = context.watch<AiSettingsProvider>();
    // Motor/anahtar değişince oynatıcı durumu da güncellensin.
    final tts = context.watch<TtsSettingsProvider>();
    final topics = _availableTopics(news);
    // TTS ayarları (motor, ses, anahtar) değiştiyse motoru yenile.
    if (_ttsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureEngine();
      });
    }

    // AI provider hazır + ready ama _error "yapılandırılmamış" diyorsa,
    // kullanıcı Settings'te düzeltmiş demektir → error'ı temizle.
    if (_error != null &&
        ai.initialized &&
        ai.isReady() &&
        _error!.contains('yapılandır')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _error = null);
          // Otomatik tekrar üret.
          _refresh();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesli Brifing'),
        actions: [
          // Uyku zamanlayıcısı menüsü — saat ikonu, aktifse rengi değişir.
          PopupMenuButton<int>(
            tooltip: _sleepDuration == null
                ? 'Uyku zamanlayıcısı'
                : 'Uyku: ${_sleepDuration!.inMinutes} dk',
            icon: Icon(
              _sleepDuration == null ? AppIcons.moon : AppIcons.moon,
              color: _sleepDuration == null
                  ? null
                  : Theme.of(context).colorScheme.primary,
            ),
            onSelected: (minutes) {
              HapticFeedback.selectionClick();
              if (minutes == 0) {
                _setSleepTimer(null);
              } else {
                _setSleepTimer(Duration(minutes: minutes));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 0, child: Text('Kapalı')),
              const PopupMenuItem(value: 15, child: Text('15 dakika')),
              const PopupMenuItem(value: 30, child: Text('30 dakika')),
              const PopupMenuItem(value: 60, child: Text('1 saat')),
            ],
          ),
          IconButton(
            tooltip: 'Bu konu için yeniden oluştur',
            onPressed: _generating ? null : _refresh,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopicChipsRow(
              topics: topics,
              selectedKey: _topic.cacheKey,
              cachedKeys: _cache.keys.toSet(),
              onSelect: _selectTopic,
              disabled: _generating,
            ),
            if (_market != null && _market!.hasAny) ...[
              const SizedBox(height: 4),
              MarketMiniWidget(
                snapshot: _market,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WeatherLocationScreen(),
                    ),
                  );
                  if (!mounted) return;
                  // Geri döndüğünde yeni şehir için hava + brifing yenile.
                  await _loadMarket();
                  await _refresh();
                },
              ),
              const SizedBox(height: 4),
            ],
            if (_ttsWarning != null) _TtsWarningBanner(message: _ttsWarning!),
            Expanded(child: _buildBody(context, cs, textTheme)),
            _PlayerBar(
              speaking: _player.isPlaying,
              paused: _player.isPaused,
              hasBriefing:
                  _player.utterances.isNotEmpty &&
                  ((_activeEngine == TtsEngineKind.system &&
                          _ttsReady &&
                          _ttsSupported) ||
                      (_activeEngine == TtsEngineKind.openai &&
                          tts.hasOpenaiTtsKey) ||
                      (_activeEngine == TtsEngineKind.elevenlabs &&
                          tts.hasElevenLabsKey) ||
                      _activeEngine == TtsEngineKind.edge),
              speedMultiplier: _player.speed,
              pitch: _player.pitch,
              pitchSupported: _player.supportsPitch,
              sleepEndsAt: _sleepEndsAt,
              utteranceIndex: _player.index,
              utteranceCount: _player.utterances.length,
              onPlay: () {
                HapticFeedback.selectionClick();
                _player.play();
              },
              onPause: () {
                HapticFeedback.selectionClick();
                _player.pause();
              },
              onStop: () {
                HapticFeedback.selectionClick();
                _player.stop();
              },
              onRestart: _restart,
              onSkipPrev: _player.skipPrevious,
              onSkipNext: _player.skipNext,
              onSeekTo: _player.seek,
              onSpeedChanged: _player.setSpeed,
              onPitchChanged: _player.setPitch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, TextTheme tt) {
    if (_generating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              '${_topic.displayName} hazırlanıyor…',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Yapay zeka son haberlerden bir özet yazıyor.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.alertCircle, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: tt.bodyMedium),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _refresh,
                  child: const Text('Tekrar dene'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                  ),
                  child: const Text('AI ayarları'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_briefing == null) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (_topic.category?.color ?? cs.primary).withValues(
                      alpha: 0.18,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _topic.category?.icon ?? AppIcons.broadcast,
                    color: _topic.category?.color ?? cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _topic.displayName,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_player.utterances.length} cümle • '
                        'yapay zeka tarafından son haberlerden derlenmiştir.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _HighlightedText(
            utterances: _player.utterances,
            currentIndex: _player.index,
            active: _player.isPlaying || _player.isPaused,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CachedBriefing {
  const _CachedBriefing(this.text, this.utterances);
  final String text;
  final List<String> utterances;
}
