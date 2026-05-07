import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_formatter.dart';
import '../data/models/article.dart';
import '../providers/bookmark_provider.dart';
import '../providers/keyword_filter_provider.dart';
import '../providers/reading_history_provider.dart';
import '../providers/reading_theme_provider.dart';
import 'article_image.dart';

class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.showBookmark = true,
  });

  final Article article;
  final VoidCallback onTap;
  final bool showBookmark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cat = article.category;

    final wasRead = context.select<ReadingHistoryProvider, bool>(
      (h) => h.wasRead(article.id),
    );
    final compact = context.select<ReadingThemeProvider, bool>(
      (t) => t.isCompact,
    );

    final imageSize = compact ? 80.0 : 124.0;
    final imageHeight = compact ? 66.0 : 100.0;
    final verticalPad = compact ? 10.0 : 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Opacity(
          opacity: wasRead ? 0.62 : 1.0,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 18, vertical: verticalPad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'card-img-${article.id}',
                  child: ArticleImage(
                    url: article.imageUrl,
                    articleUrl: article.sourceUrl,
                    width: imageSize,
                    height: imageHeight,
                    borderRadius: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cat.color,
                              ),
                            ),
                          ),
                          if (wasRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 11,
                                      color: cs.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Okundu',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Keyword match rozeti — kullanıcının ilgi
                          // duyduğu kelimelerden birine eşleşiyorsa
                          // primary renkte vurgulayıcı badge.
                          _KeywordMatchBadge(article: article),
                          const Spacer(),
                          if (showBookmark)
                            _BookmarkButton(article: article),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        maxLines: compact ? 2 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                          letterSpacing: -0.2,
                          fontSize: compact ? 14 : null,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormatter.relative(article.publishedAt),
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.bolt_outlined,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            // v2 (özetleyici): okuma süresi yerine özet uzunluğu.
                            '${article.readMinutes} dk özet',
                            style: textTheme.bodySmall,
                          ),
                          if (article.sourceName.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  article.sourceName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurfaceVariant,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FeaturedArticleCard extends StatelessWidget {
  const FeaturedArticleCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cat = article.category;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'featured-img-${article.id}',
                child: ArticleImage(
                  url: article.imageUrl,
                  articleUrl: article.sourceUrl,
                  fit: BoxFit.cover,
                  borderRadius: 22,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xCC000000),
                      Color(0xEE000000),
                    ],
                    stops: [0.0, 0.45, 0.85, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cat.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        height: 1.22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          article.author,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.schedule_outlined,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${article.readMinutes} dk özet',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeywordMatchBadge extends StatelessWidget {
  const _KeywordMatchBadge({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final matched = context.select<KeywordFilterProvider, List<String>>(
      (p) => p.matchedKeywords(article),
    );
    if (matched.isEmpty) return const SizedBox.shrink();
    final shown = matched.length == 1
        ? matched.first
        : '${matched.first} +${matched.length - 1}';
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag, size: 10, color: cs.primary),
            const SizedBox(width: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                shown,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookmarks = context.watch<BookmarkProvider>();
    final saved = bookmarks.isBookmarked(article.id);
    return InkResponse(
      radius: 22,
      onTap: () => context.read<BookmarkProvider>().toggle(article.id),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_outline,
          key: ValueKey(saved),
          size: 20,
          color: saved ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
