part of '../article_detail_screen.dart';

/// A persistent, accessible link back to the publisher.
class _OriginalLinkCta extends StatelessWidget {
  const _OriginalLinkCta({
    required this.accent,
    required this.host,
    required this.onPressed,
  });
  final Color accent;
  final String host;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stackHost =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: cs.onSurface,
            foregroundColor: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.externalLink, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Kaynağında oku',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (stackHost && host.isNotEmpty)
                      Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.surface.withValues(alpha: .8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (!stackHost && host.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.surface.withValues(alpha: .8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One reading aid section, with no competing promotional cards.
class _ArticleHelpSection extends StatelessWidget {
  const _ArticleHelpSection({
    required this.article,
    required this.isSepia,
    required this.sepiaText,
  });
  final Article article;
  final bool isSepia;
  final Color sepiaText;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Okuma yardımı',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 24, height: 1.25),
                ),
              ),
            ),
            if (MediaQuery.textScalerOf(context).scale(16) <= 24) ...[
              const SizedBox(width: 12),
              const PusulaMascot(pose: MascotPose.curious, size: 52),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _AiSummarySection(
          article: article,
          isSepia: isSepia,
          sepiaText: sepiaText,
        ),
        const Divider(height: 1),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            ArticleQaSheet.show(context, article);
          },
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurface,
            minimumSize: const Size(0, 64),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.messageQuestion,
                size: 24,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Bu haber hakkında soru sor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 22, color: cs.onSurfaceVariant),
            ],
          ),
        ),
        const Divider(height: 1),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('language-help-${article.id}'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
            leading: Icon(AppIcons.scale, size: 24, color: cs.onSurfaceVariant),
            title: const Text(
              'Haberin dilini incele',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            children: [BiasIndicator(article: article, embedded: true)],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _BookmarkAction extends StatelessWidget {
  const _BookmarkAction({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<BookmarkProvider, bool>(
      (b) => b.isBookmarked(article.id),
    );
    return _ScrimIconButton(
      icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
      tooltip: saved ? 'Kayıttan çıkar' : 'Kaydet',
      activeAccent: saved,
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<BookmarkProvider>().toggleArticle(article);
      },
    );
  }
}

/// Detay ekranının üst köşelerinde, fotoğraf üstünde duran action butonu.
///
/// Tek scrim renkli pill: dark blur arkaplan + beyaz icon. SliverAppBar
/// hem expand'de (resim arkada) hem collapsed'de (surface arkada) iyi
/// kontrast sağlıyor — koyu pill her ikisinde de ayırt edilebilir.
class _ScrimIconButton extends StatelessWidget {
  const _ScrimIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.activeAccent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool activeAccent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = activeAccent ? cs.primaryContainer : cs.surface;
    final fg = activeAccent ? cs.onPrimaryContainer : cs.onSurface;
    final button = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(icon, key: ValueKey(icon), size: 18, color: fg),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Kaynak adı + logosu birlikte gösteren küçük rozet.
/// Yazar satırında yuvarlak kaynak logosu. Kaynak katalogda varsa logoyu,
/// yoksa marka rengiyle baş-harf placeholder'ı gösterir.
class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.sourceName});

  final String sourceName;
  static const double _r = 18;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = _SourceBadge._findSource(sourceName);
    final brandColor = source?.brandColor ?? cs.primary;

    return Container(
      width: _r * 2,
      height: _r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brandColor.withValues(alpha: 0.10),
        border: Border.all(
          color: brandColor.withValues(alpha: 0.32),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: source != null
            ? CachedNetworkImage(
                imageUrl: source.logoUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => _letter(brandColor, source.shortName),
                errorWidget: (_, _, _) => _letter(brandColor, source.shortName),
              )
            : _letter(brandColor, sourceName.isNotEmpty ? sourceName : '?'),
      ),
    );
  }

  Widget _letter(Color color, String name) => Container(
    alignment: Alignment.center,
    color: color.withValues(alpha: 0.15),
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
    ),
  );
}

///
/// Detay ekranının üstünde (ÖZET satırında) ve AI özet kartında kullanılır.
/// Logo `NewsSourceCatalog`'tan kaynak adıyla eşleşirse Google s2/favicons
/// üzerinden gelir; bulunamazsa marka harf placeholder gösterilir.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.sourceName});

  final String sourceName;
  static const double size = 18;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = _findSource(sourceName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (source?.brandColor ?? cs.outlineVariant).withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (source != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: size,
                height: size,
                color: source.brandColor.withValues(alpha: 0.10),
                child: CachedNetworkImage(
                  imageUrl: source.logoUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) =>
                      _LogoLetter(source: source, size: size),
                  errorWidget: (_, _, _) =>
                      _LogoLetter(source: source, size: size),
                ),
              ),
            )
          else
            Icon(AppIcons.world, size: size, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            sourceName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  static NewsSource? _findSource(String name) {
    for (final s in NewsSourceCatalog.all) {
      if (s.name == name || s.shortName == name) return s;
    }
    return null;
  }
}

class _LogoLetter extends StatelessWidget {
  const _LogoLetter({required this.source, required this.size});
  final NewsSource source;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: source.brandColor.withValues(alpha: 0.18),
      child: Text(
        source.shortName.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: source.brandColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.55,
        ),
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArticleImage(
                url: article.imageUrl,
                articleUrl: article.sourceUrl,
                width: 88,
                height: 72,
                borderRadius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormatter.relative(article.publishedAt),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
