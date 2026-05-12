import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/ai/openrouter_client.dart';
import '../../core/tts/briefing_audio_cache.dart';
import '../../core/tts/briefing_audio_handler.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/repositories/daily_briefing_service.dart';
import '../../data/repositories/elevenlabs_tts_service.dart';
import '../../data/repositories/market_widget_service.dart';
import '../../data/repositories/openai_tts_service.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/market_mini_widget.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/weather_location_screen.dart';

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
  final OpenAiTtsService _openaiTts = OpenAiTtsService();
  final ElevenLabsTtsService _elevenLabsTts = ElevenLabsTtsService();
  final MarketWidgetService _marketService = MarketWidgetService();
  StreamSubscription<void>? _audioCompleteSub;
  StreamSubscription<BriefingLockAction>? _lockActionSub;
  MarketSnapshot? _market;
  // Aktif OpenAI playback'in completer'ı. Pause/stop bunu manuel olarak
  // complete eder; aksi halde subscription cancel edilince completer
  // resolved olmaz ve `await` 3 dk timeout'a kadar asılır.
  Completer<void>? _openaiPlaybackCompleter;

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
  bool _speaking = false;
  bool _paused = false;
  double _speechRate = 0.50; // 0.0-1.0; flutter_tts'te 0.5 ≈ normal hız
  // Ton ayarı: 0.5 (kalın) — 2.0 (ince), 1.0 = nötr.
  double _pitch = 1.0;

  // ─── Uyku zamanlayıcısı ───
  // Belirlenen sürenin sonunda playback otomatik durur. UI dropdown'unda
  // "Kapalı / 15 / 30 / 60 dk" seçilebilir; null = kapalı.
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  DateTime? _sleepEndsAt;

  // Cümle parçaları + ilerleme.
  List<String> _utterances = const [];
  int _utteranceIndex = 0;
  // Her play/pause/stop eyleminde artar; _playFromIndex bu değeri yakalar.
  // Eski döngüler nesil uyuşmazlığı görünce erken çıkar — race condition yok.
  int _playGeneration = 0;
  Completer<void>? _utteranceCompleter;

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
    _bootstrap();
    _wireLockScreenActions();
  }

  /// Lock screen / bildirim panel butonlarını dinle. Kullanıcı oradan
  /// play/pause/stop/next/prev'e basınca bizim screen state'inde
  /// tetikle.
  void _wireLockScreenActions() {
    if (!BriefingAudioHandler.isBooted) return;
    _lockActionSub =
        BriefingAudioHandler.instance.actions.listen((action) {
      if (!mounted) return;
      switch (action) {
        case BriefingLockAction.play:
          _play();
          break;
        case BriefingLockAction.pause:
          _pause();
          break;
        case BriefingLockAction.stop:
          _stop();
          break;
        case BriefingLockAction.skipNext:
          if (_utteranceIndex < _utterances.length - 1) {
            _utteranceIndex++;
            _stop().then((_) => _play());
          }
          break;
        case BriefingLockAction.skipPrev:
          if (_utteranceIndex > 0) {
            _utteranceIndex--;
            _stop().then((_) => _play());
          }
          break;
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
    final canPlay = _ttsReady ||
        _activeEngine == TtsEngineKind.openai ||
        _activeEngine == TtsEngineKind.elevenlabs;
    if (_briefing != null && _briefing!.isNotEmpty && canPlay) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _play();
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
      await ai.whenInitialized
          .timeout(const Duration(milliseconds: 2000));
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
      await _safeCall('setSharedInstance',
          () async => _tts.setSharedInstance(true));
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
      _ttsWarning = 'Cihazınızda Türkçe TTS sesi yüklü olmayabilir. '
          'Sistem ayarları > Erişilebilirlik > Konuşma Sentezi\'nden '
          'Türkçe ses paketini yüklemeyi deneyin.';
    }

    await _safeCall(
        'setSpeechRate', () async => _tts.setSpeechRate(_speechRate));
    await _safeCall('setPitch', () async => _tts.setPitch(_pitch));
    await _safeCall('setVolume', () async => _tts.setVolume(1.0));
    await _safeCall('awaitSpeakCompletion',
        () async => _tts.awaitSpeakCompletion(false));

    // Handler kayıtları sync — try/catch'e gerek yok ama güvenlik için.
    try {
      _tts.setStartHandler(_onSpeechStart);
      _tts.setCompletionHandler(_onSpeechCompletion);
      _tts.setCancelHandler(_onSpeechCancel);
      _tts.setErrorHandler(_onSpeechError);
      _tts.setPauseHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _paused = true;
        });
      });
      _tts.setContinueHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = true;
          _paused = false;
        });
      });
    } catch (e) {
      debugPrint('[Pusula][TTS] handler kaydı hata: $e');
    }

    _ttsReady = true;
    if (mounted) setState(() {});
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
      debugPrint('[Pusula][TTS] $name: PlatformException → ${e.code} ${e.message}');
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

  void _onSpeechStart() {
    if (!mounted) return;
    setState(() {
      _speaking = true;
      _paused = false;
    });
  }

  void _onSpeechCompletion() {
    final completer = _utteranceCompleter;
    _utteranceCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _onSpeechCancel() {
    final completer = _utteranceCompleter;
    _utteranceCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    if (!mounted) return;
    // _paused kasıtlı olarak sıfırlanmıyor — _pause()/_stop() yönetir.
    // Sıfırlansaydı _pause() sonrası loop devam ederdi (race condition).
    setState(() => _speaking = false);
  }

  void _onSpeechError(dynamic msg) {
    debugPrint('[Pusula][TTS] error: $msg');
    final completer = _utteranceCompleter;
    _utteranceCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _paused = false;
      _ttsWarning = 'Sesli okuma sırasında hata: $msg';
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _audioCompleteSub?.cancel();
    _lockActionSub?.cancel();
    _sleepTimer?.cancel();
    _localAudioPlayer.dispose();
    _elevenLabsTts.close();
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
        await _stop();
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
      context.read<AiSettingsProvider>().ttsEngine;

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
          _utterances = cached.utterances;
          _utteranceIndex = 0;
          _generating = false;
          _error = null;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _generating = true;
      _error = null;
      _briefing = null;
      _utterances = const [];
      _utteranceIndex = 0;
    });

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
        maxTokens: 700,
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
        _utterances = parts;
        _utteranceIndex = 0;
        _generating = false;
      });
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
    if (_topic.isGeneral) return news.latest(take: 6);
    final cat = _topic.category!;
    final list = news.articlesOf(cat.id);
    if (list.isEmpty) return const [];
    final sorted = List<Article>.of(list)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted.take(6).toList(growable: false);
  }

  // ─────────────── Playback ───────────────

  /// Sırayla tüm cümleleri çalar. Aktif motora göre branch:
  ///   - system: flutter_tts.speak() + completion handler
  ///   - openai: OpenAI'dan MP3 indir, audioplayers ile çal, onPlayerComplete bekle
  Future<void> _playFromIndex(int startIndex) async {
    if (_utterances.isEmpty) return;
    final engine = _activeEngine;
    // Sistem TTS hazır değilse sadece sistem motoru engellensin;
    // OpenAI ve ElevenLabs API tabanlı olduğu için sistem TTS'e ihtiyaç duymaz.
    if (engine == TtsEngineKind.system && !_ttsReady) return;

    final generation = _playGeneration;
    setState(() {
      _utteranceIndex = startIndex;
      _paused = false;
      _speaking = true;
    });

    for (var i = startIndex; i < _utterances.length; i++) {
      if (!mounted) return;
      if (generation != _playGeneration) return;
      _utteranceIndex = i;
      try {
        if (engine == TtsEngineKind.openai) {
          await _speakViaOpenAi(_utterances[i]);
        } else if (engine == TtsEngineKind.elevenlabs) {
          await _speakViaElevenLabs(_utterances[i]);
        } else {
          await _speakViaSystem(_utterances[i]);
        }
      } catch (e) {
        debugPrint('[Pusula][TTS] cümle $i için hata: $e');
        if (!mounted) return;
        setState(() {
          _ttsWarning = 'Sesli okuma sırasında hata: $e';
        });
        break;
      }
      if (!mounted) return;
      if (generation != _playGeneration) return;
    }
    if (!mounted) return;
    if (generation == _playGeneration) {
      setState(() => _speaking = false);
    }
  }

  Future<void> _speakViaSystem(String text) async {
    final completer = Completer<void>();
    _utteranceCompleter = completer;
    try {
      final result = await _tts.speak(text);
      if (result == 0) {
        if (!completer.isCompleted) completer.complete();
        throw Exception('Sistem TTS speak() 0 döndü.');
      }
    } on MissingPluginException catch (e) {
      if (!completer.isCompleted) completer.complete();
      if (mounted) {
        setState(() {
          _ttsSupported = false;
          _ttsWarning = 'Sesli okuma motoru bu cihazda kullanılamıyor. '
              'Uygulamayı tamamen kapatıp yeniden açın (hot reload yetmez).';
        });
      }
      throw Exception(e.message ?? 'MissingPlugin');
    }
    await completer.future;
  }

  Future<void> _speakViaOpenAi(String text) async {
    final ai = context.read<AiSettingsProvider>();
    if (ai.openaiTtsKey.isEmpty) {
      throw const OpenAiTtsException(
        'OpenAI TTS anahtarı yok. Ayarlar > Yapay Zeka > Sesli Okuma '
        'Motoru bölümünden girin.',
      );
    }
    // OpenAI ses hızı: 0.25-4.0 (1.0 normal). Bizim slider 0.30-0.70 idi
    // (flutter_tts skalası). Burayı OpenAI skalasına çeviriyoruz.
    // 0.30 → 0.75 (yavaş), 0.50 → 1.0 (normal), 0.70 → 1.25 (hızlı).
    final openaiSpeed = (0.5 + (_speechRate - 0.5) * 1.5).clamp(0.5, 2.0);

    // 1) Disk cache kontrolü — aynı (text + voice + model + speed)
    //    kombinasyonu için MP3 varsa API'ye gitmeden direkt çal.
    final cached = await BriefingAudioCache.find(
      text: text,
      voice: ai.openaiTtsVoice,
      model: ai.openaiTtsModel,
      speed: openaiSpeed,
    );

    Source playerSource;
    if (cached != null) {
      debugPrint('[Pusula][OpenAI TTS] cache hit: ${cached.path}');
      playerSource = DeviceFileSource(cached.path);
    } else {
      // 2) Cache miss → API çağrısı + disk'e kaydet.
      final bytes = await _openaiTts.synthesize(
        apiKey: ai.openaiTtsKey,
        text: text,
        voice: ai.openaiTtsVoice,
        model: ai.openaiTtsModel,
        speed: openaiSpeed,
      );
      // ignore: unawaited_futures
      BriefingAudioCache.store(
        text: text,
        voice: ai.openaiTtsVoice,
        model: ai.openaiTtsModel,
        speed: openaiSpeed,
        bytes: bytes,
      );
      playerSource = BytesSource(bytes);
    }

    // 3) Çal + sonraki cümleye geç completion ile.
    // Race fix: `_openaiPlaybackCompleter` state field; pause/stop bunu
    // manuel complete edince `await` hemen sonlanır, 3 dk asılı kalmaz.
    await _audioCompleteSub?.cancel();
    final completer = Completer<void>();
    _openaiPlaybackCompleter = completer;
    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(playerSource);
      await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          debugPrint('[Pusula][OpenAI TTS] playback timeout');
        },
      );
    } finally {
      await _audioCompleteSub?.cancel();
      _audioCompleteSub = null;
      // Aynı completer artık aktif değil — referansı temizle.
      if (identical(_openaiPlaybackCompleter, completer)) {
        _openaiPlaybackCompleter = null;
      }
    }
  }

  Future<void> _speakViaElevenLabs(String text) async {
    final ai = context.read<AiSettingsProvider>();
    if (ai.elevenLabsApiKey.isEmpty) {
      throw const ElevenLabsException(
        'ElevenLabs API anahtarı yok. Ayarlar > Yapay Zeka > Sesli Okuma '
        'Motoru bölümünden girin.',
      );
    }

    // ElevenLabs hız aralığı: 0.7–1.2 (dar aralık).
    // Bizim slider 0.30–0.70 flutter_tts skalasına dayanıyor.
    // 0.30 → 0.7, 0.50 → 1.0, 0.70 → 1.2 olacak şekilde lineer eşliyoruz.
    const double speedForCache = 1.0;

    // 1) Disk cache kontrolü — aynı (text + voice + model + speed)
    //    kombinasyonu için MP3 varsa API'ye gitmeden direkt çal.
    final cached = await BriefingAudioCache.find(
      text: text,
      voice: ai.elevenLabsVoiceId,
      model: ai.elevenLabsModelId,
      speed: speedForCache,
    );

    Source playerSource;
    if (cached != null) {
      debugPrint('[Pusula][ElevenLabs TTS] cache hit: ${cached.path}');
      playerSource = DeviceFileSource(cached.path);
    } else {
      // 2) Cache miss → API çağrısı + disk'e kaydet.
      final bytes = await _elevenLabsTts.synthesize(
        apiKey: ai.elevenLabsApiKey,
        text: text,
        voiceId: ai.elevenLabsVoiceId,
        modelId: ai.elevenLabsModelId,
        stability: ai.elevenLabsStability,
        similarityBoost: ai.elevenLabsSimilarityBoost,
      );
      // ignore: unawaited_futures
      BriefingAudioCache.store(
        text: text,
        voice: ai.elevenLabsVoiceId,
        model: ai.elevenLabsModelId,
        speed: speedForCache,
        bytes: bytes,
      );
      playerSource = BytesSource(bytes);
    }

    // 3) Çal + sonraki cümleye geç completion ile.
    await _audioCompleteSub?.cancel();
    final completer = Completer<void>();
    _openaiPlaybackCompleter = completer;
    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(playerSource);
      await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          debugPrint('[Pusula][ElevenLabs TTS] playback timeout');
        },
      );
    } finally {
      await _audioCompleteSub?.cancel();
      _audioCompleteSub = null;
      if (identical(_openaiPlaybackCompleter, completer)) {
        _openaiPlaybackCompleter = null;
      }
    }
  }

  Future<void> _play() async {
    if (_utterances.isEmpty) return;
    final engine = _activeEngine;
    // API-tabanlı motorlar sistem TTS'e ihtiyaç duymaz.
    if (engine == TtsEngineKind.system && !_ttsReady) return;
    HapticFeedback.selectionClick();
    if (_paused) {
      await _playFromIndex(_utteranceIndex);
    } else {
      await _playFromIndex(0);
    }
  }

  Future<void> _pause() async {
    HapticFeedback.selectionClick();
    _playGeneration++;
    setState(() => _paused = true);
    final engine = _activeEngine;
    if (engine == TtsEngineKind.openai ||
        engine == TtsEngineKind.elevenlabs) {
      await _audioPlayer.stop();
      // Aktif completer'ı manuel complete et — `_speakVia*`'deki
      // `await completer.future` döner, döngü `_paused` üzerinden break eder.
      final c = _openaiPlaybackCompleter;
      if (c != null && !c.isCompleted) c.complete();
      _audioCompleteSub?.cancel();
      _audioCompleteSub = null;
    } else {
      await _tts.stop();
    }
  }

  Future<void> _stop() async {
    HapticFeedback.selectionClick();
    _playGeneration++;
    setState(() {
      _paused = false;
      _utteranceIndex = 0;
      _speaking = false;
    });
    final engine = _activeEngine;
    if (engine == TtsEngineKind.openai ||
        engine == TtsEngineKind.elevenlabs) {
      await _audioPlayer.stop();
      final c = _openaiPlaybackCompleter;
      if (c != null && !c.isCompleted) c.complete();
      _audioCompleteSub?.cancel();
      _audioCompleteSub = null;
    } else {
      await _tts.stop();
    }
  }

  Future<void> _restart() async {
    await _stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _play();
  }

  Future<void> _selectTopic(BriefingTopic t) async {
    if (t.cacheKey == _topic.cacheKey) return;
    HapticFeedback.selectionClick();
    await _stop();
    setState(() {
      _topic = t;
      _error = null;
    });
    await _generate();
    if (!mounted) return;
    final canPlayAfterSelect = _ttsReady ||
        _activeEngine == TtsEngineKind.openai ||
        _activeEngine == TtsEngineKind.elevenlabs;
    if (_briefing != null && canPlayAfterSelect) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _play();
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await _stop();
    await _generate(forceRefresh: true);
    if (!mounted) return;
    final canPlayAfterRefresh = _ttsReady ||
        _activeEngine == TtsEngineKind.openai ||
        _activeEngine == TtsEngineKind.elevenlabs;
    if (_briefing != null && canPlayAfterRefresh) _play();
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
    final topics = _availableTopics(news);

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
              _sleepDuration == null
                  ? Icons.bedtime_outlined
                  : Icons.bedtime,
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
            icon: const Icon(Icons.refresh),
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
            Expanded(
              child: _buildBody(context, cs, textTheme),
            ),
            _PlayerBar(
              speaking: _speaking,
              paused: _paused,
              hasBriefing: _utterances.isNotEmpty &&
                  ((_activeEngine == TtsEngineKind.system &&
                          _ttsReady &&
                          _ttsSupported) ||
                      (_activeEngine == TtsEngineKind.openai &&
                          context.watch<AiSettingsProvider>().hasOpenaiTtsKey) ||
                      (_activeEngine == TtsEngineKind.elevenlabs &&
                          context.watch<AiSettingsProvider>().hasElevenLabsKey)),
              speechRate: _speechRate,
              pitch: _pitch,
              sleepEndsAt: _sleepEndsAt,
              progress: _utterances.isEmpty
                  ? 0.0
                  : (_utteranceIndex / _utterances.length).clamp(0.0, 1.0),
              onPlay: _play,
              onPause: _pause,
              onStop: _stop,
              onRestart: _restart,
              onRateChanged: (r) async {
                setState(() => _speechRate = r);
                await _safeCall(
                    'setSpeechRate', () async => _tts.setSpeechRate(r));
                if (_speaking) {
                  final idx = _utteranceIndex;
                  _playGeneration++;
                  if (!mounted) return;
                  final engine = _activeEngine;
                  if (engine == TtsEngineKind.openai ||
                      engine == TtsEngineKind.elevenlabs) {
                    await _audioPlayer.stop();
                    final c = _openaiPlaybackCompleter;
                    if (c != null && !c.isCompleted) c.complete();
                    _audioCompleteSub?.cancel();
                    _audioCompleteSub = null;
                  } else {
                    await _tts.stop();
                  }
                  if (!mounted) return;
                  await _playFromIndex(idx);
                }
              },
              onPitchChanged: (p) async {
                setState(() => _pitch = p);
                await _safeCall(
                    'setPitch', () async => _tts.setPitch(p));
                // Sistem TTS ses tonunu hot-update etmez; konuşma sürerken
                // şu anki cümleyi durdurup tekrar başlatmak yerine
                // kullanıcıya bir sonraki cümleden itibaren etki etsin.
              },
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
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
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
                    MaterialPageRoute(
                      builder: (_) => const AiSettingsScreen(),
                    ),
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
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.14),
                  cs.tertiary.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (_topic.category?.color ?? cs.primary)
                        .withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _topic.category?.icon ?? Icons.podcasts,
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
                        '${_utterances.length} cümle • '
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
            utterances: _utterances,
            currentIndex: _utteranceIndex,
            speaking: _speaking,
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

class _TopicChipsRow extends StatelessWidget {
  const _TopicChipsRow({
    required this.topics,
    required this.selectedKey,
    required this.cachedKeys,
    required this.onSelect,
    required this.disabled,
  });

  final List<BriefingTopic> topics;
  final String selectedKey;
  final Set<String> cachedKeys;
  final ValueChanged<BriefingTopic> onSelect;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: topics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = topics[i];
          final selected = t.cacheKey == selectedKey;
          final hasCached = cachedKeys.contains(t.cacheKey);
          final accent = t.category?.color ?? cs.primary;
          return ChoiceChip(
            avatar: Icon(
              t.category?.icon ?? Icons.podcasts,
              size: 16,
              color: selected ? cs.onPrimary : accent,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.isGeneral ? 'Genel' : t.category!.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
                if (hasCached && !selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle,
                      size: 12, color: cs.onSurfaceVariant),
                ],
              ],
            ),
            selected: selected,
            onSelected: disabled ? null : (_) => onSelect(t),
            selectedColor: accent,
            backgroundColor: cs.surfaceContainerHighest,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

class _TtsWarningBanner extends StatelessWidget {
  const _TtsWarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: cs.onTertiaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.utterances,
    required this.currentIndex,
    required this.speaking,
  });

  final List<String> utterances;
  final int currentIndex;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SelectableText.rich(
      TextSpan(
        children: [
          for (var i = 0; i < utterances.length; i++)
            TextSpan(
              text: '${utterances[i]} ',
              style: TextStyle(
                color: cs.onSurface,
                backgroundColor: speaking && i == currentIndex
                    ? cs.primary.withValues(alpha: 0.18)
                    : null,
                fontWeight: speaking && i == currentIndex
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
        ],
      ),
      style: textTheme.bodyLarge?.copyWith(
        height: 1.7,
        fontSize: 16,
      ),
    );
  }
}

class _PlayerBar extends StatefulWidget {
  const _PlayerBar({
    required this.speaking,
    required this.paused,
    required this.hasBriefing,
    required this.speechRate,
    required this.pitch,
    required this.sleepEndsAt,
    required this.progress,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onRestart,
    required this.onRateChanged,
    required this.onPitchChanged,
  });

  final bool speaking;
  final bool paused;
  final bool hasBriefing;
  final double speechRate;
  final double pitch;
  final DateTime? sleepEndsAt;
  final double progress;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final ValueChanged<double> onRateChanged;
  final ValueChanged<double> onPitchChanged;

  @override
  State<_PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<_PlayerBar> {
  // Gelişmiş kontroller (pitch) varsayılanda kapalı; expand'te açılır.
  bool _showAdvanced = false;
  // Uyku zamanlayıcısı kalan süre tickeri.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _maybeStartTicker();
  }

  @override
  void didUpdateWidget(covariant _PlayerBar old) {
    super.didUpdateWidget(old);
    if (widget.sleepEndsAt != old.sleepEndsAt) {
      _ticker?.cancel();
      _ticker = null;
      _maybeStartTicker();
    }
  }

  void _maybeStartTicker() {
    if (widget.sleepEndsAt == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _sleepCountdown() {
    final ends = widget.sleepEndsAt;
    if (ends == null) return '';
    final remaining = ends.difference(DateTime.now());
    if (remaining.isNegative) return '';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sleepText = _sleepCountdown();
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.progress,
              minHeight: 3,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          if (sleepText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bedtime, size: 13, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  'Uyku: $sleepText',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Hız: ${_rateLabel(widget.speechRate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: widget.speechRate,
                  min: 0.30,
                  max: 0.70,
                  divisions: 8,
                  onChanged: widget.hasBriefing ? widget.onRateChanged : null,
                ),
              ),
              IconButton(
                tooltip: _showAdvanced
                    ? 'Gelişmiş ayarları gizle'
                    : 'Ton ayarı',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(
                  () => _showAdvanced = !_showAdvanced,
                ),
                icon: Icon(
                  _showAdvanced
                      ? Icons.tune
                      : Icons.tune_outlined,
                  color: _showAdvanced ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Gelişmiş: ton (pitch) sürgüsü.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showAdvanced
                ? Row(
                    children: [
                      Icon(Icons.graphic_eq,
                          size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Ton: ${_pitchLabel(widget.pitch)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.pitch,
                          min: 0.5,
                          max: 1.8,
                          divisions: 13,
                          onChanged: widget.hasBriefing
                              ? widget.onPitchChanged
                              : null,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Durdur',
                onPressed: widget.hasBriefing ? widget.onStop : null,
                icon: const Icon(Icons.stop_rounded),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 64,
                height: 64,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: !widget.hasBriefing
                      ? null
                      : (widget.speaking ? widget.onPause : widget.onPlay),
                  child: Icon(
                    widget.speaking
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                tooltip: 'Yeniden başlat',
                onPressed: widget.hasBriefing ? widget.onRestart : null,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rateLabel(double r) {
    if (r <= 0.35) return 'Yavaş';
    if (r <= 0.45) return 'Orta-yavaş';
    if (r <= 0.55) return 'Normal';
    if (r <= 0.62) return 'Hızlı';
    return 'Çok hızlı';
  }

  String _pitchLabel(double p) {
    if (p <= 0.7) return 'Çok kalın';
    if (p <= 0.9) return 'Kalın';
    if (p <= 1.1) return 'Nötr';
    if (p <= 1.4) return 'İnce';
    return 'Çok ince';
  }
}
