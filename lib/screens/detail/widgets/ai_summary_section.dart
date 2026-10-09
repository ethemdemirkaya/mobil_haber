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
  final _readAlongNotifier =
      ValueNotifier<ReadAlongState>(ReadAlongState.idle);

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
      return _DisabledHint(
        reason: !ai.enabled
            ? 'Yapay zeka özetleri kapalı.'
            : 'API anahtarı veya model eksik.',
      );
    }

    final cached = ai.cachedSummary(widget.article.id);
    final loading = ai.loadingArticleId == widget.article.id;

    if (cached == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ai.lastError != null && !loading)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ai.lastError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── Sesli Özetle — birincil aksiyon ──────────────────────────
          ArticleAudioSummaryButton(
            article: widget.article,
            large: true,
            expand: true,
            readAlongNotifier: _readAlongNotifier,
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: loading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      context
                          .read<AiSettingsProvider>()
                          .summarize(widget.article);
                    },
              child: AnimatedOpacity(
                opacity: loading ? 0.55 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 13, horizontal: 18),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.primary),
                        )
                      else
                        Icon(Icons.auto_awesome_outlined,
                            size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        loading ? 'Özet üretiliyor…' : 'Sadece metin özetle',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Özet mevcut — metin kartı + sesli dinle butonu ──────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: 0.10),
                cs.primary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'YAPAY ZEKA ÖZETİ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ai.currentModelLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: ai.isLoadingFor(widget.article.id)
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            final aiRef = context.read<AiSettingsProvider>();
                            await aiRef.invalidate(widget.article.id);
                            if (!context.mounted) return;
                            await aiRef.summarize(widget.article);
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ai.isLoadingFor(widget.article.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Sesli okuma sırasında aktif satır vurgulanır ──────────
              ValueListenableBuilder<ReadAlongState>(
                valueListenable: _readAlongNotifier,
                builder: (context, state, _) => _ReadAlongText(
                  text: cached,
                  readAlongState: state,
                  baseStyle: TextStyle(
                    color: widget.isSepia ? widget.sepiaText : cs.onSurface,
                    fontSize: 14,
                    height: 1.55,
                    fontFamily: widget.isSepia ? 'serif' : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Sesli dinle — özet üretildikten sonra hemen kullanılabilir ──
        ArticleAudioSummaryButton(
          article: widget.article,
          large: true,
          expand: true,
          readAlongNotifier: _readAlongNotifier,
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

    final active =
        readAlongState.activeLine.clamp(0, lines.length - 1);

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (int i = 0; i < lines.length; i++) ...[
            TextSpan(
              text: lines[i],
              style: i == active
                  ? TextStyle(
                      backgroundColor:
                          cs.primary.withValues(alpha: 0.18),
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    )
                  : i < active
                      ? TextStyle(
                          color: baseStyle.color?.withValues(alpha: 0.45),
                        )
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: cs.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Yapay zeka özetlerini etkinleştir',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
