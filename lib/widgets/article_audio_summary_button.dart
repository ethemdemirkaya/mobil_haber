import 'package:pusula_news/core/theme/app_icons.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../core/tts/briefing_player.dart';
import '../core/tts/tts_engine_factory.dart';
import '../data/models/article.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/tts_settings_provider.dart';

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

class _ArticleAudioSummaryButtonState extends State<ArticleAudioSummaryButton> {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final TtsEngineFactory _engines =
      TtsEngineFactory(systemTts: _tts, player: _audioPlayer);

  /// Sesli brifingle aynı oynatıcı: cümle sırası, geç gelen olay koruması,
  /// bulut motoru düşerse cihaz sesine geçiş. Eskiden bu buton kendi cümle
  /// döngüsünü ve geçici MP3 dosyalarını yönetiyordu; Edge 403 verince
  /// sessizce susuyordu.
  final BriefingPlayer _player = BriefingPlayer();

  bool _preparing = false;
  List<String> _displayLines = const [];
  bool _wasPlaying = false;
  Object? _reportedError;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerChanged);
    _initSystemTts();
  }

  Future<void> _initSystemTts() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {}
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final playing = _player.isPlaying;
    final notifier = widget.readAlongNotifier;
    if (playing && _displayLines.isNotEmpty) {
      // Cümle → ekran satırı oransal eşleme.
      final count = _player.utterances.length;
      final line = count == 0
          ? 0
          : ((_player.index / count) * _displayLines.length)
              .floor()
              .clamp(0, _displayLines.length - 1);
      notifier?.value = ReadAlongState(
        lines: _displayLines,
        activeLine: line,
        isActive: true,
      );
    } else if (_wasPlaying && !playing) {
      notifier?.value = ReadAlongState.idle;
    }
    _wasPlaying = playing;
    // Hata oynatıcıyı duraklatır; her hatayı bir kez göster. (Burada
    // stop() çağırmak dinleyiciyi yeniden tetikleyip döngüye sokardı.)
    final err = _player.error;
    if (err != null && !identical(err, _reportedError)) {
      _reportedError = err;
      _showError('Sesli okuma hatası: ${TtsEngineFactory.shortError(err)}');
    }
    setState(() {});
  }

  /// Özet metnini TTS için cümlelere böler (madde işaretleri atılır).
  List<String> _toSentences(String text) {
    final parts = <String>[];
    for (final line in text.split('\n')) {
      final clean = line.replaceAll('•', '').trim();
      if (clean.isEmpty) continue;
      for (final s in clean.split(RegExp(r'(?<=[^\d\s][.!?])\s+'))) {
        final t = s.trim();
        if (t.isNotEmpty) parts.add(t);
      }
    }
    return parts.isEmpty ? [text.trim()] : parts;
  }

  /// Özet metnini ekranda gösterilecek satırlara böler (bullet'lar korunur).
  List<String> _toDisplayLines(String text) => text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  Future<void> _onTap() async {
    HapticFeedback.selectionClick();

    if (_player.isPlaying || _player.isPaused) {
      await _player.stop();
      widget.readAlongNotifier?.value = ReadAlongState.idle;
      return;
    }
    if (_preparing) return;

    final ai = context.read<AiSettingsProvider>();
    final tts = context.read<TtsSettingsProvider>();
    if (!ai.isReady()) {
      _showError('Yapay zeka özeti için AI ayarlarını yapılandırın');
      return;
    }

    String? summary = ai.cachedSummary(widget.article.id);
    if (summary == null) {
      setState(() => _preparing = true);
      await ai.summarize(widget.article);
      if (!mounted) return;
      setState(() => _preparing = false);
      summary = ai.cachedSummary(widget.article.id);
      if (summary == null) {
        // Ör. haberin özetlenecek kadar metni yoksa sebebini göster.
        _showError(ai.lastError ?? 'Özet üretilemedi.');
        return;
      }
    }

    final kind = tts.ttsEngine;
    await _player.setEngine(_engines.build(
      tts,
      onFallback: (e) => _showError(
        '${kind.label} şu an kullanılamıyor '
        '(${TtsEngineFactory.shortError(e)}). Cihazın sesiyle okunuyor.',
      ),
    ));
    _displayLines = _toDisplayLines(summary);
    await _player.load(_toSentences(summary));
    await _player.play();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _player.dispose();
    _audioPlayer.dispose();
    _engines.close();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final aiLoading = ai.isLoadingFor(widget.article.id);
    final effective = aiLoading || _preparing
        ? _AudioState.loading
        : (_player.isPlaying ? _AudioState.speaking : _AudioState.idle);

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
    final loading = state == _AudioState.loading;
    final speaking = state == _AudioState.speaking;
    return FilledButton(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: cs.onSurface,
        foregroundColor: cs.surface,
        minimumSize: const Size(0, 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(speaking ? AppIcons.playerStop : AppIcons.headphones, size: 24),
          const SizedBox(width: 14),
          Flexible(
            fit: expand ? FlexFit.tight : FlexFit.loose,
            child: Text(
              loading
                  ? 'Özet hazırlanıyor…'
                  : speaking
                  ? 'Sesli okumayı durdur'
                  : 'Sesli özeti dinle',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.surface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
                      isSpeaking ? AppIcons.playerStop : AppIcons.volume,
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
