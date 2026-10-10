part of '../daily_briefing_screen.dart';

class _PlayerBar extends StatefulWidget {
  const _PlayerBar({
    required this.speaking,
    required this.paused,
    required this.hasBriefing,
    required this.speedMultiplier,
    required this.pitch,
    required this.pitchSupported,
    required this.sleepEndsAt,
    required this.utteranceIndex,
    required this.utteranceCount,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onRestart,
    required this.onSkipPrev,
    required this.onSkipNext,
    required this.onSeekTo,
    required this.onSpeedChanged,
    required this.onPitchChanged,
  });

  final bool speaking;
  final bool paused;
  final bool hasBriefing;
  final double speedMultiplier;
  final double pitch;

  /// Ton ayarı yalnızca sistem TTS'te çalışır; diğer motorlarda gizlenir.
  final bool pitchSupported;
  final DateTime? sleepEndsAt;
  final int utteranceIndex;
  final int utteranceCount;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onSkipPrev;
  final VoidCallback onSkipNext;
  final ValueChanged<int> onSeekTo;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onPitchChanged;

  @override
  State<_PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<_PlayerBar> {
  bool _showAdvanced = false;
  bool _dragging = false;
  double? _dragValue;
  Timer? _ticker;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const _speedLabels = ['0.75×', '1×', '1.25×', '1.5×', '2×'];

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
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sleepText = _sleepCountdown();
    final count = widget.utteranceCount;
    final idx = widget.utteranceIndex;
    final sliderVal = _dragging
        ? (_dragValue ?? idx.toDouble())
        : idx.toDouble();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Seekable utterance slider ──
          Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${idx + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: count > 1 ? sliderVal.clamp(0, count - 1.0) : 0,
                    min: 0,
                    max: count > 1 ? count - 1.0 : 1,
                    divisions: count > 1 ? count - 1 : null,
                    onChanged: widget.hasBriefing && count > 1
                        ? (v) => setState(() {
                            _dragging = true;
                            _dragValue = v;
                          })
                        : null,
                    onChangeEnd: widget.hasBriefing && count > 1
                        ? (v) {
                            setState(() {
                              _dragging = false;
                              _dragValue = null;
                            });
                            widget.onSeekTo(v.round());
                          }
                        : null,
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // ── Sleep countdown ──
          if (sleepText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.moon, size: 13, color: cs.primary),
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
          const SizedBox(height: 4),
          // ── Speed chips ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _speeds.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(
                      _speedLabels[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: widget.speedMultiplier == _speeds[i],
                    onSelected: widget.hasBriefing
                        ? (_) => widget.onSpeedChanged(_speeds[i])
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
                ),
              if (widget.pitchSupported) const SizedBox(width: 4),
              if (widget.pitchSupported)
                IconButton(
                  tooltip: _showAdvanced
                      ? 'Gelişmiş ayarları gizle'
                      : 'Ton ayarı',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _showAdvanced = !_showAdvanced),
                  icon: Icon(
                    _showAdvanced
                        ? AppIcons.adjustmentsHorizontal
                        : AppIcons.adjustmentsHorizontal,
                    color: _showAdvanced ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          // ── Collapsible pitch slider ──
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showAdvanced && widget.pitchSupported
                ? Row(
                    children: [
                      Icon(
                        AppIcons.waveSine,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
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
          const SizedBox(height: 4),
          // ── Playback controls ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop
              IconButton.filledTonal(
                tooltip: 'Durdur',
                onPressed: widget.hasBriefing ? widget.onStop : null,
                icon: const Icon(AppIcons.playerStop),
              ),
              const SizedBox(width: 4),
              // Skip prev
              IconButton(
                tooltip: 'Önceki cümle',
                iconSize: 28,
                onPressed: widget.hasBriefing && idx > 0
                    ? widget.onSkipPrev
                    : null,
                icon: const Icon(AppIcons.playerSkipBack),
              ),
              const SizedBox(width: 4),
              // Play / Pause
              SizedBox(
                width: 60,
                height: 60,
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
                        ? AppIcons.playerPause
                        : AppIcons.playerPlay,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Skip next
              IconButton(
                tooltip: 'Sonraki cümle',
                iconSize: 28,
                onPressed: widget.hasBriefing && idx < count - 1
                    ? widget.onSkipNext
                    : null,
                icon: const Icon(AppIcons.playerSkipForward),
              ),
              const SizedBox(width: 4),
              // Restart
              IconButton.filledTonal(
                tooltip: 'Yeniden başlat',
                onPressed: widget.hasBriefing ? widget.onRestart : null,
                icon: const Icon(AppIcons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pitchLabel(double p) {
    if (p <= 0.7) return 'Çok kalın';
    if (p <= 0.9) return 'Kalın';
    if (p <= 1.1) return 'Nötr';
    if (p <= 1.4) return 'İnce';
    return 'Çok ince';
  }
}
