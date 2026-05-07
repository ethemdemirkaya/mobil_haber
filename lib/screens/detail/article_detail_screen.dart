import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/article_image.dart';
import '../../widgets/section_header.dart';

class ArticleDetailScreen extends StatelessWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cat = article.category;

    final related = context.select<NewsProvider, List<Article>>(
      (n) => n.related(article),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            systemOverlayStyle: cs.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            actions: [
              IconButton(
                tooltip: 'Paylaş',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => _showSnack(context, 'Paylaşım hazırlanıyor…'),
              ),
              _BookmarkAction(article: article),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'article-img-${article.id}',
                    child: ArticleImage(
                      url: article.imageUrl,
                      borderRadius: 0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 14, color: cat.color),
                        const SizedBox(width: 6),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cat.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    article.title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            cs.primaryContainer.withValues(alpha: 0.7),
                        child: Text(
                          _initials(article.author),
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.author,
                              style: textTheme.titleSmall,
                            ),
                            Text(
                              DateFormatter.full(article.publishedAt),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_outlined,
                                size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${article.readMinutes} dk okuma',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    article.summary,
                    style: textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(
                      height: 1,
                      color:
                          cs.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 18),
                  Text(
                    article.content,
                    style: textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          if (related.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'İlgili haberler'),
            ),
            SliverList.builder(
              itemCount: related.length,
              itemBuilder: (context, index) {
                final r = related[index];
                return _RelatedTile(article: r);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
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
    return IconButton(
      tooltip: saved ? 'Kayıttan çıkar' : 'Kaydet',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_outline,
          key: ValueKey(saved),
        ),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        context.read<BookmarkProvider>().toggle(article.id);
      },
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
