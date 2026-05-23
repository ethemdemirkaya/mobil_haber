import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/models/article.dart';
import '../data/repositories/edge_tts_service.dart';
import '../data/repositories/elevenlabs_tts_service.dart';
import '../data/repositories/openai_tts_service.dart';
import '../providers/ai_settings_provider.dart';

enum _AudioState { idle, loading, speaking }

/// Sesli okuma sırasında hangi satırın okunduğunu diğer widget'lara bildiren durum.
///
/// Sistem TTS: [activeLine] her cümlede güncellenir.
/// MP3 TTS (OpenAI/ElevenLabs/Edge): [activeLine] elapsed-time oranına göre hesaplanır.
class ReadAlongState {
  const ReadAlongState({
    this.lines = const [],
    this.activeLine = -1,
    this.isActive = false,
  });

  static const ReadAlongState idle = ReadAlongState();

  /// Özetin satırlara (• bullet / paragraf) bölünmüş hali — sadece gösterim.
  final List<String> lines;

  /// Şu an okunan satırın 0 tabanlı indeksi. -1 = hiç satır aktif değil.
  final int activeLine;

  /// Sesli okuma devam ediyor mu?
  final bool isActive;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Haberi AI ile özetleyip seçili TTS motoruyla sesli okuyan buton.
///
/// Motorlar: system (flutter_tts), openai, elevenlabs, edge.
/// [readAlongNotifier] — isteğe bağlı; sesli okuma durumunu (satır vurgusu)
/// ebeveyne aktarır. Ebeveyn bu notifier'ı metni görüntüleyen widget'a da
/// verir, böylece okuma satır-satır vurgulanır.
class ArticleAudioSummaryButton extends StatefulWidget {
  const ArticleAudioSummaryButton({
    super.key,
    required this.article,
    this.large = false,
    this.expand = false,
    this.readAlongNotifier,
  });

  final Article article;
  final bool large;
  final bool expand;

  /// Dışarıdan verilirse buton, okuma ilerledikçe bu notifier'ı günceller.
  final ValueNotifier<ReadAlongState>? readAlongNotifier;

  @override
  State<ArticleAudioSummaryButton> createState() =>
      _ArticleAudioSummaryButtonState();
}

class _ArticleAudioSummaryButtonState
    extends State<ArticleAudioSummaryButton> {
  // ─── TTS motorları ──────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OpenAiTtsService _openaiTts = OpenAiTtsService();
  final ElevenLabsTtsService _elevenLabsTts = ElevenLabsTtsService();
  final EdgeTtsService _edgeTts = EdgeTtsService();

  // ─── Durum ──────────────────────────────────────────────────────────────
  _AudioState _state = _AudioState.idle;

  /// Sistem TTS'te cümle-cümle döngüsü için tamamlama sinyali.
  Completer<void>? _systemTtsDone;

  /// MP3 motorlarında ses süresi (pozisyon oranı için).
  Duration? _audioDuration;

  /// MP3 motorlarında o an görüntülenen display satırları.
  List<String> _currentDisplayLines = const [];

  /// Döngüden çıkış bayrağı (stop tuşu).
  bool _cancelled = false;

  /// Geçici MP3 dosyası — oynatma bittikten sonra silinir.
  String? _tempAudioPath;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initSystemTts();
    _audioPlayer.onDurationChanged.listen((d) {
      _audioDuration = d;
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted || _audioDuration == null) return;
      final dur = _audioDuration!.inMilliseconds;
      if (dur <= 0 || _currentDisplayLines.isEmpty) return;
      final progress = pos.inMilliseconds / dur;
      final lineIdx = (progress * _currentDisplayLines.length)
          .floor()
          .clamp(0, _currentDisplayLines.length - 1);
      widget.readAlongNotifier?.value = ReadAlongState(
        lines: _currentDisplayLines,
        activeLine: lineIdx,
        isActive: true,
      );
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _state = _AudioState.idle);
      widget.readAlongNotifier?.value = ReadAlongState.idle;
      _deleteTempFile();
    });
  }

  Future<void> _initSystemTts() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        // Cümle-cümle döngüsünde her cümle bitince sinyali tetikle.
        _systemTtsDone?.complete();
        _systemTtsDone = null;
      });
      _tts.setCancelHandler(() {
        _systemTtsDone?.complete();
        _systemTtsDone = null;
        if (mounted) setState(() => _state = _AudioState.idle);
        widget.readAlongNotifier?.value = ReadAlongState.idle;
      });
      _tts.setErrorHandler((_) {
        _systemTtsDone?.complete();
        _systemTtsDone = null;
        if (mounted) setState(() => _state = _AudioState.idle);
        widget.readAlongNotifier?.value = ReadAlongState.idle;
      });
    } catch (_) {}
  }

  // ─── Yardımcı metodlar ─────────────────────────────────────────────────

  /// Özet metnini TTS için cümlelere böler.
  List<String> _toSentences(String text) {
    // Önce satıra göre böl (bullet maddeleri), sonra içlerindeki noktalı
    // cümleleri de ayır — her biri kısa bir TTS çağrısı olsun.
    final parts = <String>[];
    for (final line in text.split('\n')) {
      final clean = line.replaceAll('•', '').trim();
      if (clean.isEmpty) continue;
      // Cümle-içi bölme: '.', '!' veya '?' ardından boşluk varsa ayır.
      final sub = clean.split(RegExp(r'(?<=[.!?])\s+'));
      for (final s in sub) {
        final t = s.trim();
        if (t.isNotEmpty) parts.add(t);
      }
    }
    return parts.isEmpty ? [text.trim()] : parts;
  }

  /// Özet metnini ekranda gösterilecek satırlara böler (bullet'lar korunur).
  List<String> _toDisplayLines(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Temizlenmiş TTS metni: bullet ve satır sonlarını kaldırır.
  String _cleanForTts(String text) {
    return text
        .split('\n')
        .map((l) => l.replaceAll('•', '').trim())
        .where((l) => l.isNotEmpty)
        .join('. ');
  }

  /// MP3 byte'larını geçici dosyaya yazar; yol döner.
  Future<String> _writeTempMp3(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/pusula_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  void _deleteTempFile() {
    final p = _tempAudioPath;
    _tempAudioPath = null;
    if (p != null) {
      File(p).delete().ignore();
    }
  }

  // ─── Ana aksiyon ───────────────────────────────────────────────────────

  Future<void> _onTap() async {
    HapticFeedback.selectionClick();

    // Oynatma varsa durdur.
    if (_state == _AudioState.speaking) {
      _cancelled = true;
      await _tts.stop();
      await _audioPlayer.stop();
      _deleteTempFile();
      if (mounted) setState(() => _state = _AudioState.idle);
      widget.readAlongNotifier?.value = ReadAlongState.idle;
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

    // Özet yoksa önce üret.
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

    if (!mounted) return;
    setState(() => _state = _AudioState.loading);
    _cancelled = false;

    try {
      switch (ai.ttsEngine) {
        case TtsEngineKind.system:
          await _speakWithSystem(summary);

        case TtsEngineKind.openai:
          if (!ai.hasOpenaiTtsKey) {
            _showError('OpenAI TTS anahtarı ayarlanmamış.');
            return;
          }
          final bytes = await _openaiTts.synthesize(
            apiKey: ai.openaiTtsKey,
            text: _cleanForTts(summary),
            voice: ai.openaiTtsVoice,
            model: ai.openaiTtsModel,
          );
          if (!mounted) return;
          await _playMp3(bytes, summary);

        case TtsEngineKind.elevenlabs:
          if (!ai.hasElevenLabsKey) {
            _showError('ElevenLabs API anahtarı ayarlanmamış.');
            return;
          }
          final bytes = await _elevenLabsTts.synthesize(
            apiKey: ai.elevenLabsApiKey,
            text: _cleanForTts(summary),
            voiceId: ai.elevenLabsVoiceId,
            modelId: ai.elevenLabsModelId,
            stability: ai.elevenLabsStability,
            similarityBoost: ai.elevenLabsSimilarityBoost,
          );
          if (!mounted) return;
          await _playMp3(bytes, summary);

        case TtsEngineKind.edge:
          final bytes = await _edgeTts.synthesize(
            text: _cleanForTts(summary),
            voice: ai.edgeTtsVoice,
          );
          if (!mounted) return;
          await _playMp3(bytes, summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _AudioState.idle);
        widget.readAlongNotifier?.value = ReadAlongState.idle;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesli okuma hatası: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Sistem TTS: cümle-cümle döngüsü → her cümlede satır vurgusu güncellenir.
  Future<void> _speakWithSystem(String summary) async {
    final sentences = _toSentences(summary);
    final displayLines = _toDisplayLines(summary);
    if (sentences.isEmpty || !mounted) return;

    setState(() => _state = _AudioState.speaking);

    for (var i = 0; i < sentences.length; i++) {
      if (_cancelled || !mounted) break;

      // Cümle → ekran satırı oransal eşleme.
      final lineIdx = ((i / sentences.length) * displayLines.length)
          .floor()
          .clamp(0, displayLines.length - 1);
      widget.readAlongNotifier?.value = ReadAlongState(
        lines: displayLines,
        activeLine: lineIdx,
        isActive: true,
      );

      _systemTtsDone = Completer<void>();
      await _tts.speak(sentences[i]);
      // Cümle tamamlanana (veya durdurulana) kadar bekle — max 30 sn.
      await _systemTtsDone!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
      _systemTtsDone = null;
    }

    if (mounted && !_cancelled) {
      setState(() => _state = _AudioState.idle);
    }
    widget.readAlongNotifier?.value = ReadAlongState.idle;
  }

  /// MP3 byte'larını geçici dosyaya yazar ve audioplayers ile oynatır.
  /// Position listener aracılığıyla satır vurgusu otomatik güncellenir.
  Future<void> _playMp3(List<int> bytes, String summary) async {
    _deleteTempFile();
    _currentDisplayLines = _toDisplayLines(summary);
    _audioDuration = null;

    final path = await _writeTempMp3(bytes);
    _tempAudioPath = path;

    if (!mounted) {
      _deleteTempFile();
      return;
    }

    widget.readAlongNotifier?.value = ReadAlongState(
      lines: _currentDisplayLines,
      activeLine: 0,
      isActive: true,
    );
    setState(() => _state = _AudioState.speaking);
    await _audioPlayer.play(DeviceFileSource(path));
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _state = _AudioState.idle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _cancelled = true;
    _tts.stop();
    _audioPlayer.dispose();
    _deleteTempFile();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────
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
    final cs = Theme.of(context).colorScheme;
    final isLoading = state == _AudioState.loading;
    final isSpeaking = state == _AudioState.speaking;

    final Color baseColor = isSpeaking ? cs.error : cs.primary;
    final Color endColor = isSpeaking
        ? Color.lerp(cs.error, Colors.deepOrange.shade700, 0.35)!
        : Color.lerp(cs.primary, cs.tertiary, 0.28)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isSpeaking
                              ? Icons.stop_circle_outlined
                              : Icons.record_voice_over_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLoading
                            ? 'Özet hazırlanıyor…'
                            : isSpeaking
                                ? 'Durdur'
                                : 'Sesli Özetle',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLoading
                            ? 'Yapay zeka özeti hazırlıyor'
                            : isSpeaking
                                ? 'Sesli okuma devam ediyor'
                                : 'AI özeti sesli dinle',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSpeaking
                      ? Icons.equalizer_rounded
                      : isLoading
                          ? Icons.hourglass_top_rounded
                          : Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.70),
                  size: 20,
                ),
              ],
            ),
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
