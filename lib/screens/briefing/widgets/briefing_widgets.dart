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
        fontSize: 20,
        fontFamily: 'Newsreader',
      ),
    );
  }
}
