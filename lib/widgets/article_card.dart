import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/date_formatter.dart';
import '../data/models/article.dart';
import '../providers/bookmark_provider.dart';
import '../providers/keyword_filter_provider.dart';
import '../providers/news_provider.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final compact = context.select<ReadingThemeProvider, bool>(
      (p) => p.isCompact,
    );
    final read = context.select<ReadingHistoryProvider, bool>(
      (p) => p.wasRead(article.id),
    );
    final sources = context.select<NewsProvider, int>(
      (p) => p.trendingSourceCount(article.id),
    );
    final matched = context.select<KeywordFilterProvider, List<String>>(
      (p) => p.matchedKeywords(article),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: compact ? 12 : 18,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.category.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .9,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      article.title,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: compact ? 18 : 21,
                        height: 1.16,
                        color: read ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      [
                        if (article.sourceName.isNotEmpty) article.sourceName,
                        DateFormatter.relative(article.publishedAt),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (sources >= 2 || matched.isNotEmpty || read) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (sources >= 2)
                            Text(
                              '$sources kaynak',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                              ),
                            ),
                          if (matched.isNotEmpty)
                            Text(
                              '#${matched.first}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          if (read)
                            Text('Okundu', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Hero(
                    tag: 'card-img-${article.id}',
                    child: ArticleImage(
                      url: article.imageUrl,
                      articleUrl: article.sourceUrl,
                      width: compact ? 76 : 94,
                      height: compact ? 76 : 94,
                      borderRadius: 6,
                    ),
                  ),
                  if (showBookmark) _BookmarkButton(article: article),
                ],
              ),
            ],
          ),
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
    final saved = context.select<BookmarkProvider, bool>(
      (p) => p.isBookmarked(article.id),
    );
    return IconButton(
      tooltip: saved ? 'Kaydedilenlerden çıkar' : 'Sonra okumak için kaydet',
      onPressed: () => context.read<BookmarkProvider>().toggleArticle(article),
      iconSize: 20,
      icon: Icon(saved ? AppIcons.bookmarkFilled : AppIcons.bookmark),
      color: saved
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'featured-img-${article.id}',
                child: ArticleImage(
                  url: article.imageUrl,
                  articleUrl: article.sourceUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              [
                article.category.name.toUpperCase(),
                if (article.sourceName.isNotEmpty) article.sourceName,
              ].join('  /  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              article.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(height: 1.12),
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormatter.relative(article.publishedAt)} · ${article.readMinutes} dk okuma',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
