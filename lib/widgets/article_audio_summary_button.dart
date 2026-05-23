import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../data/models/article.dart';
import '../data/repositories/edge_tts_service.dart';
import '../data/repositories/elevenlabs_tts_service.dart';
import '../data/repositories/openai_tts_service.dart';
import '../providers/ai_settings_provider.dart';

enum _AudioState { idle, loading, speaking }

/// Haberi AI ile özetleyip seçili TTS motoruyla sesli okuyan buton.
///
/// Desteklenen motorlar: system (flutter_tts), openai, elevenlabs, edge.
/// [large]  = true  → büyük pill buton (detay ekranı)
/// [expand] = true  → butonu mevcut genişliğe yayar (detay ekranında tam genişlik)
class ArticleAudioSummaryButton extends StatefulWidget {
  const ArticleAudioSummaryButton({
    super.key,
    required this.article,
    this.large = false,
    this.expand = false,
  });

  final Article article;
  final bool large;
  final bool expand;

  @override
  State<ArticleAudioSummaryButton> createState() =>
      _ArticleAudioSummaryButtonState();
}

class _ArticleAudioSummaryButtonState
    extends State<ArticleAudioSummaryButton> {
  // System TTS
  final FlutterTts _tts = FlutterTts();

  // MP3-based engines
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OpenAiTtsService _openaiTts = OpenAiTtsService();
  final ElevenLabsTtsService _elevenLabsTts = ElevenLabsTtsService();
  final EdgeTtsService _edgeTts = EdgeTtsService();

  _AudioState _state = _AudioState.idle;

  @override
  void initState() {
    super.initState();
    _initSystemTts();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _state = _AudioState.idle);
    });
  }

  Future<void> _initSystemTts() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _state = _AudioState.idle);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _state = _AudioState.idle);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _state = _AudioState.idle);
      });
    } catch (_) {}
  }

  Future<void> _stopAll() async {
    await _tts.stop();
    await _audioPlayer.stop();
  }

  Future<void> _onTap() async {
    HapticFeedback.selectionClick();

    if (_state == _AudioState.speaking) {
      await _stopAll();
      if (mounted) setState(() => _state = _AudioState.idle);
      return;
    }

    if (_state == _AudioState.loading) return;

    final ai = context.read<AiSettingsProvider>();

    if (!ai.isReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yapay zeka özeti için AI ayarlarını yapılandırın'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Özet yoksa önce üret
    String? summary = ai.cachedSummary(widget.article.id);
    if (summary == null) {
      if (mounted) setState(() => _state = _AudioState.loading);
      await ai.summarize(widget.article);
      if (!mounted) return;
      summary = ai.cachedSummary(widget.article.id);
      if (summary == null) {
        if (mounted) setState(() => _state = _AudioState.idle);
        return;
      }
    }

    // Madde işaretlerini ve satır sonlarını TTS için temizle
    final cleaned = summary
        .split('\n')
        .map((l) => l.replaceAll('•', '').trim())
        .where((l) => l.isNotEmpty)
        .join('. ');

    if (!mounted) return;
    setState(() => _state = _AudioState.loading);

    try {
      switch (ai.ttsEngine) {
        case TtsEngineKind.system:
          setState(() => _state = _AudioState.speaking);
          await _tts.speak(cleaned);

        case TtsEngineKind.openai:
          if (!ai.hasOpenaiTtsKey) {
            _showEngineError('OpenAI TTS anahtarı ayarlanmamış.');
            return;
          }
          final bytes = await _openaiTts.synthesize(
            apiKey: ai.openaiTtsKey,
            text: cleaned,
            voice: ai.openaiTtsVoice,
            model: ai.openaiTtsModel,
          );
          if (!mounted) return;
          setState(() => _state = _AudioState.speaking);
          await _audioPlayer.play(BytesSource(bytes));

        case TtsEngineKind.elevenlabs:
          if (!ai.hasElevenLabsKey) {
            _showEngineError('ElevenLabs API anahtarı ayarlanmamış.');
            return;
          }
          final bytes = await _elevenLabsTts.synthesize(
            apiKey: ai.elevenLabsApiKey,
            text: cleaned,
            voiceId: ai.elevenLabsVoiceId,
            modelId: ai.elevenLabsModelId,
            stability: ai.elevenLabsStability,
            similarityBoost: ai.elevenLabsSimilarityBoost,
          );
          if (!mounted) return;
          setState(() => _state = _AudioState.speaking);
          await _audioPlayer.play(BytesSource(bytes));

        case TtsEngineKind.edge:
          final bytes = await _edgeTts.synthesize(
            text: cleaned,
            voice: ai.edgeTtsVoice,
          );
          if (!mounted) return;
          setState(() => _state = _AudioState.speaking);
          await _audioPlayer.play(BytesSource(bytes));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _AudioState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesli okuma hatası: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showEngineError(String message) {
    if (!mounted) return;
    setState(() => _state = _AudioState.idle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final aiLoading = ai.isLoadingFor(widget.article.id);
    final effective = aiLoading ? _AudioState.loading : _state;

    return widget.large
        ? _LargeButton(state: effective, onTap: _onTap, expand: widget.expand)
        : _CompactButton(state: effective, onTap: _onTap);
  }
}

// ─── Büyük pill buton (detay ekranı) ─────────────────────────────────────────

class _LargeButton extends StatelessWidget {
  const _LargeButton({
    required this.state,
    required this.onTap,
    this.expand = false,
  });

  final _AudioState state;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isLoading = state == _AudioState.loading;
    final isSpeaking = state == _AudioState.speaking;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(50),
      elevation: 3,
      shadowColor: Colors.black45,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        splashColor: const Color(0x221565C0),
        highlightColor: const Color(0x111565C0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: isLoading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF1565C0)),
                      )
                    : Icon(
                        isSpeaking
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                        size: 22,
                        color: const Color(0xFF1565C0),
                      ),
              ),
              const SizedBox(width: 10),
              Text(
                isLoading
                    ? 'Özet hazırlanıyor…'
                    : isSpeaking
                        ? 'Durdur'
                        : 'Sesli Özetle',
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kompakt buton ────────────────────────────────────────────────────────────

class _CompactButton extends StatelessWidget {
  const _CompactButton({required this.state, required this.onTap});

  final _AudioState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = state == _AudioState.loading;
    final isSpeaking = state == _AudioState.speaking;

    final color = isSpeaking ? cs.error : cs.primary;

    return InkResponse(
      radius: 22,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: isLoading
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    )
                  : Icon(
                      isSpeaking
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined,
                      size: 13,
                      color: color,
                    ),
            ),
            const SizedBox(width: 4),
            Text(
              isSpeaking ? 'Dur' : 'Dinle',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
