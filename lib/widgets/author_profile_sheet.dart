import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_formatter.dart';
import '../data/models/article.dart';
import '../providers/news_provider.dart';
import 'article_image.dart';

class AuthorProfileSheet extends StatelessWidget {
  const AuthorProfileSheet({super.key, required this.authorName});

  final String authorName;

  static Future<Article?> show(BuildContext context, String authorName) {
    return showModalBottomSheet<Article>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AuthorProfileSheet(authorName: authorName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final allArticles = context.select<NewsProvider, List<Article>>((n) {
      return n.latest(take: 9999);
    });
    final byAuthor = allArticles
        .where((a) => a.author.toLowerCase() == authorName.toLowerCase())
        .toList(growable: false);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        cs.primaryContainer.withValues(alpha: 0.7),
                    child: Text(
                      _initials(authorName),
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'mobil_haber muhabiri',
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${byAuthor.length} haber',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: byAuthor.isEmpty
                    ? Center(
                        child: Text(
                          'Bu yazara ait haber bulunamadı.',
                          style: textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: byAuthor.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final a = byAuthor[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ArticleImage(
                              url: a.imageUrl,
                              width: 56,
                              height: 56,
                              borderRadius: 12,
                            ),
                            title: Text(
                              a.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            subtitle: Text(
                              '${a.category.name} · ${DateFormatter.relative(a.publishedAt)}',
                              style: textTheme.bodySmall,
                            ),
                            onTap: () => Navigator.of(context).pop(a),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
