part of '../daily_briefing_screen.dart';

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
              t.category?.icon ?? AppIcons.broadcast,
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
                  Icon(
                    AppIcons.circleCheck,
                    size: 12,
                    color: cs.onSurfaceVariant,
                  ),
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
          Icon(AppIcons.alertTriangle, size: 18, color: cs.onTertiaryContainer),
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

/// Brifing metni; okunan cümle vurgulanır ve görünür alana kaydırılır.
class _HighlightedText extends StatefulWidget {
  const _HighlightedText({
    required this.utterances,
    required this.currentIndex,
    required this.active,
  });

  final List<String> utterances;
  final int currentIndex;

  /// Çalıyor ya da duraklatılmış — vurgu ikisinde de görünür.
  final bool active;

  @override
  State<_HighlightedText> createState() => _HighlightedTextState();
}

class _HighlightedTextState extends State<_HighlightedText> {
  double _width = 0;

  TextStyle _baseStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
            height: 1.7,
            fontSize: 20,
            fontFamily: 'Newsreader',
          );

  @override
  void didUpdateWidget(covariant _HighlightedText old) {
    super.didUpdateWidget(old);
    if (widget.active &&
        (widget.currentIndex != old.currentIndex || !old.active)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  /// Okunan cümlenin satırını ekranın üst üçte birine getirir. Eskiden
  /// metin kaymıyordu; okunan cümle çoğu zaman ekran dışında kalıyordu.
  void _scrollToCurrent() {
    if (!mounted || _width <= 0) return;
    final scrollable = Scrollable.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final scrollBox = scrollable?.context.findRenderObject() as RenderBox?;
    if (scrollable == null || box == null || scrollBox == null) return;

    var charOffset = 0;
    for (var i = 0; i < widget.currentIndex; i++) {
      charOffset += widget.utterances[i].length + 1;
    }
    final painter = TextPainter(
      text: TextSpan(
        style: _baseStyle(context),
        text: widget.utterances.map((u) => '$u ').join(),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _width);
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: charOffset),
      Rect.zero,
    );
    painter.dispose();

    final position = scrollable.position;
    final lineTop = box.localToGlobal(Offset(0, caret.dy), ancestor: scrollBox);
    final target = (position.pixels +
            lineTop.dy -
            position.viewportDimension * 0.3)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 8) return;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return SelectableText.rich(
          TextSpan(
            children: [
              for (var i = 0; i < widget.utterances.length; i++)
                TextSpan(
                  text: '${widget.utterances[i]} ',
                  style: TextStyle(
                    color: cs.onSurface,
                    backgroundColor: widget.active && i == widget.currentIndex
                        ? cs.primary.withValues(alpha: 0.18)
                        : null,
                    fontWeight: widget.active && i == widget.currentIndex
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
            ],
          ),
          style: _baseStyle(context),
        );
      },
    );
  }
}
