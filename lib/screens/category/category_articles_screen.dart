import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../providers/news_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../detail/article_detail_screen.dart';

enum _CategorySort { newest, oldest, shortRead, longRead, title }

extension on _CategorySort {
  String get label {
    switch (this) {
      case _CategorySort.newest:
        return 'En yeni';
      case _CategorySort.oldest:
        return 'En eski';
      case _CategorySort.shortRead:
        return 'En kısa özet';
      case _CategorySort.longRead:
        return 'En uzun özet';
      case _CategorySort.title:
        return 'Başlık (A-Z)';
    }
  }

  IconData get icon {
    switch (this) {
      case _CategorySort.newest:
        return Icons.schedule_outlined;
      case _CategorySort.oldest:
        return Icons.history;
      case _CategorySort.shortRead:
        return Icons.timer_outlined;
      case _CategorySort.longRead:
        return Icons.menu_book_outlined;
      case _CategorySort.title:
        return Icons.sort_by_alpha;
    }
  }
}

class CategoryArticlesScreen extends StatefulWidget {
  const CategoryArticlesScreen({super.key, required this.category});

  final NewsCategory category;

  @override
  State<CategoryArticlesScreen> createState() =>
      _CategoryArticlesScreenState();
}

class _CategoryArticlesScreenState extends State<CategoryArticlesScreen> {
  _CategorySort _sort = _CategorySort.newest;

  List<Article> _sorted(List<Article> input) {
    final list = List<Article>.of(input);
    switch (_sort) {
      case _CategorySort.newest:
        list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      case _CategorySort.oldest:
        list.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
      case _CategorySort.shortRead:
        list.sort((a, b) => a.readMinutes.compareTo(b.readMinutes));
      case _CategorySort.longRead:
        list.sort((a, b) => b.readMinutes.compareTo(a.readMinutes));
      case _CategorySort.title:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<_CategorySort>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Sırala',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            for (final s in _CategorySort.values)
              ListTile(
                leading: Icon(
                  _sort == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _sort == s
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                title: Row(
                  children: [
                    Icon(s.icon, size: 18),
                    const SizedBox(width: 10),
                    Text(s.label),
                  ],
                ),
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != _sort) {
      setState(() => _sort = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cat = widget.category;

    final raw = context.select<NewsProvider, List<Article>>(
      (n) => n.articlesOf(cat.id),
    );
    final articles = _sorted(raw);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(cat.icon, color: cat.color),
            const SizedBox(width: 8),
            Text(cat.name),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort),
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: articles.isEmpty
          ? IllustratedEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Henüz haber yok',
              subtitle:
                  '${cat.name} kategorisinde gösterilecek haber bulunamadı.',
              tone: cat.color,
            )
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        '${articles.length} haber',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_sort.icon,
                                size: 13,
                                color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              _sort.label,
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      final a = articles[index];
                      return ArticleCard(
                        article: a,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArticleDetailScreen(
                                article: a,
                                heroTag: 'card-img-${a.id}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
