part of '../article_detail_screen.dart';

/// Detay ekranında AI özet bölümü.
///
/// Üç durum:
///   1. AI ayarları kapalı/eksik → kompakt CTA "Yapay zeka özetlerini etkinleştir"
///   2. Etkin ama bu makale için cache yok → "Yapay zekayla özetle" butonu
///   3. Cache var → AI özet kartı + sesli dinle (satır-satır vurgulamalı)
class _AiSummarySection extends StatefulWidget {
  const _AiSummarySection({
    required this.article,
    required this.isSepia,
    required this.sepiaText,
  });

  final Article article;
  final bool isSepia;
  final Color sepiaText;

  @override
  State<_AiSummarySection> createState() => _AiSummarySectionState();
}

class _AiSummarySectionState extends State<_AiSummarySection> {
  /// Sesli okuma ilerlemesini metin widget'ına aktaran notifier.
  final _readAlongNotifier = ValueNotifier<ReadAlongState>(ReadAlongState.idle);

  @override
  void dispose() {
    _readAlongNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    if (!ai.isReady()) {
      return const _DisabledHint(
        reason: 'Dinleme ve özet için yapay zekayı ayarlardan açabilirsiniz.',
      );
    }
    final cached = ai.cachedSummary(widget.article.id);
    final loading = ai.loadingArticleId == widget.article.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArticleAudioSummaryButton(
          article: widget.article,
          large: true,
          expand: true,
          readAlongNotifier: _readAlongNotifier,
        ),
        if (ai.lastError != null && !loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                ai.lastError!,
                style: TextStyle(fontSize: 16, color: cs.error, height: 1.5),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (cached == null)
          TextButton(
            onPressed: loading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    context.read<AiSettingsProvider>().summarize(
                      widget.article,
                    );
                  },
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface,
              minimumSize: const Size(0, 64),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            ),
            child: Row(
              children: [
                Icon(AppIcons.article, size: 24, color: cs.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    loading ? 'Kısa özet hazırlanıyor…' : 'Kısa özeti oku',
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    AppIcons.chevronRight,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kısa özet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Özeti yeniden hazırla',
                      onPressed: loading
                          ? null
                          : () async {
                              final aiRef = context.read<AiSettingsProvider>();
                              await aiRef.invalidate(widget.article.id);
                              if (!mounted) return;
                              await aiRef.summarize(widget.article);
                            },
                      icon: const Icon(AppIcons.refresh),
                    ),
                  ],
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: ValueListenableBuilder<ReadAlongState>(
                    valueListenable: _readAlongNotifier,
                    builder: (context, state, _) => _ReadAlongText(
                      text: cached,
                      readAlongState: state,
                      baseStyle: TextStyle(
                        color: widget.isSepia ? widget.sepiaText : cs.onSurface,
                        fontSize: 18,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yapay zeka özeti · Kaynak metninden hazırlanır.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Özet metnini gösterir; sesli okuma aktifken okunan satırı vurgular.
///
/// Aktif değilse normal `SelectableText` gösterir (seçilebilir metin).
/// Aktifken: okunan satır mavi arka plan + kalın, geçmiş satırlar soluk,
/// henüz okunmamış satırlar normal.
class _ReadAlongText extends StatelessWidget {
  const _ReadAlongText({
    required this.text,
    required this.readAlongState,
    required this.baseStyle,
  });

  final String text;
  final ReadAlongState readAlongState;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!readAlongState.isActive || readAlongState.activeLine < 0) {
      return SelectableText(text, style: baseStyle);
    }

    final lines = readAlongState.lines.isNotEmpty
        ? readAlongState.lines
        : text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

    if (lines.isEmpty) {
      return SelectableText(text, style: baseStyle);
    }

    final active = readAlongState.activeLine.clamp(0, lines.length - 1);

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (int i = 0; i < lines.length; i++) ...[
            TextSpan(
              text: lines[i],
              style: i == active
                  ? TextStyle(
                      backgroundColor: cs.primary.withValues(alpha: 0.18),
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    )
                  : i < active
                  ? TextStyle(color: baseStyle.color?.withValues(alpha: 0.45))
                  : null,
            ),
            if (i < lines.length - 1) const TextSpan(text: '\n'),
          ],
        ],
      ),
    );
  }
}

class _DisabledHint extends StatelessWidget {
  const _DisabledHint({required this.reason});
  final String reason;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(reason, style: const TextStyle(fontSize: 16, height: 1.5)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
        icon: const Icon(AppIcons.settings),
        label: const Text(
          'Yapay zeka ayarlarını aç',
          style: TextStyle(fontSize: 17),
        ),
      ),
    ],
  );
}
