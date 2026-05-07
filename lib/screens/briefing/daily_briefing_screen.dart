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
/// Akış:
///   1. Açılışta NewsProvider.latest()'tan top 6 makale alınır.
///   2. AiSettingsProvider.generate() ile DailyBriefingService prompt'u
///      gönderilir, doğal akıcı 250-300 kelimelik bir Türkçe metin döner.
///   3. flutter_tts (Türkçe) ile metin oynatılır; play/pause/stop +
///      hız sürgüsü.
///
/// AI kapalıysa kullanıcıyı doğrudan AiSettingsScreen'e yönlendirir.
class DailyBriefingScreen extends StatefulWidget {
  const DailyBriefingScreen({super.key});

  @override
  State<DailyBriefingScreen> createState() => _DailyBriefingScreenState();
}

class _DailyBriefingScreenState extends State<DailyBriefingScreen> {
  final FlutterTts _tts = FlutterTts();
  final DailyBriefingService _service = DailyBriefingService();

  bool _generating = false;
  bool _speaking = false;
  bool _paused = false;
  String? _briefing;
  String? _error;
  double _speechRate = 0.5; // flutter_tts'te 0.0-1.0
  final double _pitch = 1.0;

  @override
  void initState() {
    super.initState();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generate();
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = true;
          _paused = false;
        });
      });
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _paused = false;
        });
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _paused = false;
        });
      });
      _tts.setErrorHandler((msg) {
        if (!mounted) return;
        setState(() {
          _error = 'Sesli okuma hatası: $msg';
          _speaking = false;
        });
      });
    } catch (e) {
      _error = 'TTS başlatılamadı: $e';
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _generate() async {
    final ai = context.read<AiSettingsProvider>();
    if (!ai.isReady()) {
      setState(() {
        _error = 'Yapay zeka kapalı veya yapılandırılmamış. '
            'Brifing için önce Ayarlar > Yapay Zeka\'yı tamamlayın.';
      });
      return;
    }
    final news = context.read<NewsProvider>();
    final articles = news.latest(take: 6);
    if (articles.isEmpty) {
      setState(() {
        _error = 'Henüz haber yüklenmedi. Ana sayfada birkaç saniye '
            'bekleyip tekrar deneyin.';
      });
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
      _briefing = null;
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
      if (!mounted) return;
      setState(() {
        _briefing = cleaned;
        _generating = false;
      });
      // Otomatik oku — kullanıcı brifingi açtıktan sonra ek tıklamaya
      // gerek kalmadan duymak istiyor.
      _play();
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

  Future<void> _play() async {
    if (_briefing == null || _briefing!.isEmpty) return;
    HapticFeedback.selectionClick();
    if (_paused) {
      // flutter_tts pause→resume bazı platformlarda yok; baştan oku.
      await _tts.stop();
    }
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    await _tts.speak(_briefing!);
  }

  Future<void> _pause() async {
    HapticFeedback.selectionClick();
    await _tts.pause();
    if (!mounted) return;
    setState(() {
      _paused = true;
      _speaking = false;
    });
  }

  Future<void> _stop() async {
    HapticFeedback.selectionClick();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _paused = false;
    });
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
            onPressed: _generating ? null : _generate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBody(context, cs, textTheme),
            ),
            _PlayerBar(
              speaking: _speaking,
              paused: _paused,
              hasBriefing: _briefing != null,
              speechRate: _speechRate,
              onPlay: _play,
              onPause: _pause,
              onStop: _stop,
              onRateChanged: (r) async {
                setState(() => _speechRate = r);
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
              'Son haberlerden bir gündem özeti yazıyoruz.',
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
                  onPressed: _generate,
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
                        'Yapay zeka tarafından son haberlerden derlenmiştir.',
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
          SelectableText(
            _briefing!,
            style: tt.bodyLarge?.copyWith(
              height: 1.7,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
        ],
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
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onRateChanged,
  });

  final bool speaking;
  final bool paused;
  final bool hasBriefing;
  final double speechRate;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
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
                  min: 0.25,
                  max: 0.85,
                  divisions: 6,
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
                        : (paused
                            ? Icons.play_arrow_rounded
                            : Icons.play_arrow_rounded),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                tooltip: 'Yeniden başlat',
                onPressed: hasBriefing
                    ? () {
                        onStop();
                        Future<void>.delayed(
                          const Duration(milliseconds: 120),
                          onPlay,
                        );
                      }
                    : null,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rateLabel(double r) {
    if (r <= 0.3) return 'Yavaş';
    if (r <= 0.45) return 'Orta-yavaş';
    if (r <= 0.55) return 'Normal';
    if (r <= 0.7) return 'Hızlı';
    return 'Çok hızlı';
  }
}
