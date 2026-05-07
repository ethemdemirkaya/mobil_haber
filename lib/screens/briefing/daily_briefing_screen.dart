import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/ai/openrouter_client.dart';
import '../../data/repositories/daily_briefing_service.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/news_provider.dart';
import '../settings/ai_settings_screen.dart';

/// Bugünün haberlerinden AI ile yazılmış bir brifingi sesli okutan ekran.
///
/// Yaşam döngüsü:
///   1. Açılışta loading state hemen gösterilir (boş frame yok).
///   2. Paralel olarak: TTS init + AI generate.
///   3. AI dönerse, TTS hazır olduktan sonra otomatik oku.
///   4. Cümle bazlı parçalama: her cümle ayrı `speak()` çağrısı, bir
///      önceki bittiğinde sıradaki başlar (Android TTS uzun metinde
///      kelime ortasında kesilebiliyor).
class DailyBriefingScreen extends StatefulWidget {
  const DailyBriefingScreen({super.key});

  @override
  State<DailyBriefingScreen> createState() => _DailyBriefingScreenState();
}

class _DailyBriefingScreenState extends State<DailyBriefingScreen> {
  final FlutterTts _tts = FlutterTts();
  final DailyBriefingService _service = DailyBriefingService();

  // Akış durumu — başlangıçta brifing üretiliyor → spinner gösterilsin.
  bool _generating = true;
  String? _briefing;
  String? _error;
  String? _ttsWarning; // TTS init uyarısı (Türkçe ses yok vb.)

  // TTS state
  bool _ttsReady = false;
  bool _speaking = false;
  bool _paused = false;
  double _speechRate = 0.50; // 0.0-1.0; flutter_tts'te 0.5 ≈ normal hız.
  static const double _pitch = 1.0;

  // Cümle parçaları + ilerleme.
  List<String> _utterances = const [];
  int _utteranceIndex = 0;
  Completer<void>? _utteranceCompleter; // her speak() bunu await eder.

  @override
  void initState() {
    super.initState();
    // initState async olamaz — ayrı yardımcıyla başlatıp sıraya koy.
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // TTS ve AI'yı paralel başlat — AI 5-10sn sürerken TTS init beklemesin.
    final ttsFuture = _initTts();
    final genFuture = _generate();
    await Future.wait([ttsFuture, genFuture]);
    if (!mounted) return;
    // Her ikisi de tamamlandı; brifing varsa otomatik çal.
    if (_briefing != null && _briefing!.isNotEmpty && _ttsReady) {
      // Küçük bekleme — kullanıcı UI'ı görsün, sonra ses başlasın.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _play();
    }
  }

  Future<void> _initTts() async {
    try {
      // iOS'ta arka planda da çalışsın diye shared instance + ses kategorisi
      // ayarı şart.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }

      // Türkçe dil + tipik TTS parametreleri.
      final langOk = await _tts.isLanguageAvailable('tr-TR');
      if (langOk == true) {
        await _tts.setLanguage('tr-TR');
      } else {
        // Cihazda TR yoksa default kalsın ama kullanıcıyı uyaralım.
        debugPrint('[Pusula][TTS] tr-TR yok, default dile düşülüyor.');
        _ttsWarning = 'Cihazınızda Türkçe TTS sesi yüklü değil. '
            'Sistem ayarları > Erişilebilirlik > Konuşma Sentezi\'nden '
            'Türkçe ses paketini yükleyin.';
      }
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1.0);

      // Her cümle bittiğinde sıradakini çal (chain). Bunun için
      // `awaitSpeakCompletion` KAPALI — completion handler ile yönetiyoruz.
      await _tts.awaitSpeakCompletion(false);

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

      _ttsReady = true;
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('[Pusula][TTS] init hatası: $e\n$st');
      _ttsWarning = 'Sesli okuma motoru başlatılamadı: $e';
      if (mounted) setState(() {});
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
    // Bir cümle bitti → sıradakine geç. Bittiyse durumu temizle.
    final completer = _utteranceCompleter;
    _utteranceCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _onSpeechCancel() {
    final completer = _utteranceCompleter;
    _utteranceCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
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
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _paused = false;
      // Hata gösterelim — auto-restart döngüsünden kaçın.
      _ttsWarning = 'Sesli okuma sırasında hata oluştu: $msg';
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(() {});
    _tts.setCancelHandler(() {});
    _tts.setErrorHandler((_) {});
    super.dispose();
  }

  Future<void> _generate() async {
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
    final articles = news.latest(take: 6);
    if (articles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Henüz haber yüklenmedi. Ana sayfada birkaç saniye '
            'bekleyip tekrar deneyin.';
      });
      return;
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
        systemPrompt: DailyBriefingService.systemPrompt,
        userPrompt: _service.buildUserPrompt(
          articles: articles,
          now: DateTime.now(),
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

  /// Sırayla tüm cümleleri çalar. Her cümle için speak() çağrılır,
  /// completion handler future'ını çözer, döngü sıradaki cümleye geçer.
  Future<void> _playFromIndex(int startIndex) async {
    if (!_ttsReady) {
      debugPrint('[Pusula][TTS] not ready, skip play');
      return;
    }
    if (_utterances.isEmpty) return;
    setState(() {
      _utteranceIndex = startIndex;
      _paused = false;
    });
    for (var i = startIndex; i < _utterances.length; i++) {
      if (!mounted) return;
      // Pause ya da stop çağrılırsa loop kırılır.
      if (_paused) break;
      _utteranceIndex = i;
      final completer = Completer<void>();
      _utteranceCompleter = completer;
      try {
        final result = await _tts.speak(_utterances[i]);
        // result == 1 başarı, 0 hata (Android quirky)
        if (result == 0) {
          debugPrint('[Pusula][TTS] speak returned 0 (failure) for chunk $i');
          completer.complete();
          break;
        }
      } catch (e) {
        debugPrint('[Pusula][TTS] speak threw: $e');
        if (!completer.isCompleted) completer.complete();
        break;
      }
      // Bu cümle bitene kadar bekle (completion handler complete() çağırır).
      await completer.future;
      if (!mounted) return;
      if (_paused) break;
    }
    if (!mounted) return;
    setState(() {
      _speaking = false;
    });
  }

  Future<void> _play() async {
    if (!_ttsReady) {
      debugPrint('[Pusula][TTS] _play çağrıldı ama TTS hazır değil.');
      return;
    }
    if (_utterances.isEmpty) return;
    HapticFeedback.selectionClick();
    if (_paused) {
      // Kaldığı yerden devam — _utteranceIndex orada kaldı.
      await _playFromIndex(_utteranceIndex);
    } else {
      await _playFromIndex(0);
    }
  }

  Future<void> _pause() async {
    HapticFeedback.selectionClick();
    // Mevcut cümleyi bitir, döngüyü durdur.
    setState(() => _paused = true);
    // Anında sustur:
    await _tts.stop();
  }

  Future<void> _stop() async {
    HapticFeedback.selectionClick();
    setState(() {
      _paused = false;
      _utteranceIndex = 0;
    });
    await _tts.stop();
  }

  Future<void> _restart() async {
    await _stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _play();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesli Brifing'),
        actions: [
          IconButton(
            tooltip: 'Yeniden oluştur',
            onPressed: _generating
                ? null
                : () async {
                    await _stop();
                    await _generate();
                    if (!mounted) return;
                    if (_briefing != null && _ttsReady) _play();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_ttsWarning != null) _TtsWarningBanner(message: _ttsWarning!),
            Expanded(
              child: _buildBody(context, cs, textTheme),
            ),
            _PlayerBar(
              speaking: _speaking,
              paused: _paused,
              hasBriefing: _utterances.isNotEmpty && _ttsReady,
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
                await _tts.setSpeechRate(r);
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
              'Brifing hazırlanıyor…',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Yapay zeka son haberlerden bir gündem özeti yazıyor.',
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
                  onPressed: () async {
                    await _stop();
                    await _generate();
                    if (!mounted) return;
                    if (_briefing != null && _ttsReady) _play();
                  },
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
                    color: cs.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.podcasts, color: cs.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugünün gündem brifingi',
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
          // Aktif cümleyi vurgulayarak metni göster.
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

class _TtsWarningBanner extends StatelessWidget {
  const _TtsWarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          // İlerleme çubuğu
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
