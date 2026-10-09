part of '../article_detail_screen.dart';

/// Detay ekranının alt kenarındaki sticky "Orijinali oku" CTA'sı.
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
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.open_in_new, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Orijinal haberi oku',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (host.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    host,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

/// "Bu haber hakkında AI'ya sor" CTA — özet bölümünün altında
/// gösterilen, dikkat çekici ama hafif bir promo. Tıklayınca
/// `ArticleQaSheet` bottom sheet'i açar.
class _AskAiCta extends StatelessWidget {
  const _AskAiCta({required this.article, required this.accent});

  final Article article;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          ArticleQaSheet.show(context, article);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          constraints: const BoxConstraints(minHeight: 70),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI\'ya sor',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: cs.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'BETA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Neden önemli? Arkaplan? Özet?',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
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
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
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
    final bg = activeAccent
        ? Colors.white
        : Colors.black.withValues(alpha: 0.42);
    final fg = activeAccent ? Colors.black : Colors.white;
    final button = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 18,
              color: fg,
            ),
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
            : _letter(
                brandColor,
                sourceName.isNotEmpty ? sourceName : '?',
              ),
      ),
    );
  }

  Widget _letter(Color color, String name) => Container(
        alignment: Alignment.center,
        color: color.withValues(alpha: 0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
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
          color: (source?.brandColor ?? cs.outlineVariant)
              .withValues(alpha: 0.25),
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
                  placeholder: (_, _) => _LogoLetter(source: source, size: size),
                  errorWidget: (_, _, _) =>
                      _LogoLetter(source: source, size: size),
                ),
              ),
            )
          else
            Icon(Icons.public, size: size, color: cs.onSurfaceVariant),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
