import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/ai/openrouter_client.dart';
import '../../core/tts/briefing_audio_cache.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/repositories/daily_briefing_service.dart';
import '../../data/repositories/openai_tts_service.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/news_provider.dart';
import '../settings/ai_settings_screen.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSub;

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
  static const double _pitch = 1.0;

  // Cümle parçaları + ilerleme.
  List<String> _utterances = const [];
  int _utteranceIndex = 0;
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
  }

  Future<void> _bootstrap() async {
    // TTS init + AI generate paralel başlasın — 5-10sn AI beklerken
    // TTS init harcanan süreyi tamamen örtebilir.
    final ttsFuture = _initTts();
    final genFuture = _generate();
    await Future.wait([ttsFuture, genFuture]);
    if (!mounted) return;
    if (_briefing != null && _briefing!.isNotEmpty && _ttsReady) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _play();
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
    setState(() {
      _speaking = false;
      _paused = false;
    });
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
    _audioPlayer.dispose();
    super.dispose();
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
        _error = 'Yapay zeka kapalı veya yapılandırılmamış. '
            'Brifing için önce Ayarlar > Yapay Zeka\'yı tamamlayın.';
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
      final raw = await ai.generate(
        systemPrompt: DailyBriefingService.systemPromptFor(_topic),
        userPrompt: _service.buildUserPrompt(
          articles: articles,
          now: DateTime.now(),
          topic: _topic,
        ),
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
    if (engine == TtsEngineKind.system && !_ttsReady) return;

    setState(() {
      _utteranceIndex = startIndex;
      _paused = false;
      _speaking = true;
    });

    for (var i = startIndex; i < _utterances.length; i++) {
      if (!mounted) return;
      if (_paused) break;
      _utteranceIndex = i;
      try {
        if (engine == TtsEngineKind.openai) {
          await _speakViaOpenAi(_utterances[i]);
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
      if (_paused) break;
    }
    if (!mounted) return;
    setState(() => _speaking = false);
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
    await _audioCompleteSub?.cancel();
    final completer = Completer<void>();
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
    }
  }

  Future<void> _play() async {
    if (_utterances.isEmpty) return;
    final engine = _activeEngine;
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
    setState(() => _paused = true);
    if (_activeEngine == TtsEngineKind.openai) {
      await _audioPlayer.stop();
      // Completer'ı tetikle ki döngü break etsin.
      _audioCompleteSub?.cancel();
      _audioCompleteSub = null;
    } else {
      await _tts.stop();
    }
  }

  Future<void> _stop() async {
    HapticFeedback.selectionClick();
    setState(() {
      _paused = false;
      _utteranceIndex = 0;
      _speaking = false;
    });
    if (_activeEngine == TtsEngineKind.openai) {
      await _audioPlayer.stop();
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
    if (_briefing != null && _ttsReady) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _play();
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await _stop();
    await _generate(forceRefresh: true);
    if (!mounted) return;
    if (_briefing != null && _ttsReady) _play();
  }

  // ─────────────── Build ───────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final news = context.watch<NewsProvider>();
    final topics = _availableTopics(news);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesli Brifing'),
        actions: [
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
                          context.watch<AiSettingsProvider>().hasOpenaiTtsKey)),
              speechRate: _speechRate,
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
                  await _tts.stop();
                  await _play();
                }
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

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.speaking,
    required this.paused,
    required this.hasBriefing,
    required this.speechRate,
    required this.progress,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onRestart,
    required this.onRateChanged,
  });

  final bool speaking;
  final bool paused;
  final bool hasBriefing;
  final double speechRate;
  final double progress;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final ValueChanged<double> onRateChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              value: progress,
              minHeight: 3,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Hız: ${_rateLabel(speechRate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: speechRate,
                  min: 0.30,
                  max: 0.70,
                  divisions: 8,
                  onChanged: hasBriefing ? onRateChanged : null,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Durdur',
                onPressed: hasBriefing ? onStop : null,
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
                  onPressed: !hasBriefing
                      ? null
                      : (speaking ? onPause : onPlay),
                  child: Icon(
                    speaking
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                tooltip: 'Yeniden başlat',
                onPressed: hasBriefing ? onRestart : null,
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
}
