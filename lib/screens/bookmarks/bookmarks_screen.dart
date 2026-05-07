import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../detail/article_detail_screen.dart';

enum _BookmarkSort { newest, oldest, title }

extension on _BookmarkSort {
  String get label {
    switch (this) {
      case _BookmarkSort.newest:
        return 'En yeni';
      case _BookmarkSort.oldest:
        return 'En eski';
      case _BookmarkSort.title:
        return 'Başlık (A-Z)';
    }
  }
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  String _filterCategoryId = NewsCategory.all.id;
  _BookmarkSort _sort = _BookmarkSort.newest;
  bool _groupByCategory = false;

  List<Article> _sorted(List<Article> input) {
    final list = List<Article>.of(input);
    switch (_sort) {
      case _BookmarkSort.newest:
        list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      case _BookmarkSort.oldest:
        list.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
      case _BookmarkSort.title:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  void _openDetail(Article a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: a),
      ),
    );
  }

  Future<void> _showSortSheet() async {
    final picked = await showModalBottomSheet<_BookmarkSort>(
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
            for (final s in _BookmarkSort.values)
              RadioListTile<_BookmarkSort>(
                value: s,
                groupValue: _sort,
                onChanged: (v) => Navigator.of(ctx).pop(v),
                title: Text(s.label),
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
    final bookmarks = context.watch<BookmarkProvider>();
    final news = context.watch<NewsProvider>();

    final saved = bookmarks.ids
        .map(news.byId)
        .whereType<Article>()
        .toList(growable: false);

    final usedCategoryIds = <String>{NewsCategory.all.id, ...saved.map((a) => a.categoryId)};
    final filterCategories = NewsCategory.values
        .where((c) => usedCategoryIds.contains(c.id))
        .toList(growable: false);

    final filtered = saved.where((a) {
      return _filterCategoryId == NewsCategory.all.id ||
          a.categoryId == _filterCategoryId;
    }).toList(growable: false);

    final sorted = _sorted(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydedilenler'),
        actions: [
          IconButton(
            tooltip: _groupByCategory
                ? 'Düz listeye geç'
                : 'Kategoriye göre grupla',
            icon: Icon(_groupByCategory
                ? Icons.view_list_outlined
                : Icons.dashboard_outlined),
            onPressed: () =>
                setState(() => _groupByCategory = !_groupByCategory),
          ),
          IconButton(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort),
            onPressed: _showSortSheet,
          ),
          if (saved.isNotEmpty)
            IconButton(
              tooltip: 'Tümünü sil',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
      body: saved.isEmpty
          ? IllustratedEmptyState(
              icon: Icons.bookmark_outline,
              title: 'Henüz haber kaydetmediniz',
              subtitle:
                  'Beğendiğiniz haberlerdeki kaydet simgesine dokunarak listenize ekleyebilirsiniz.',
            )
          : Column(
              children: [
                if (filterCategories.length > 1)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      itemCount: filterCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = filterCategories[i];
                        final selected = _filterCategoryId == c.id;
                        return FilterChip(
                          selected: selected,
                          label: Text(c.name),
                          avatar: Icon(c.icon, size: 16),
                          onSelected: (_) => setState(
                              () => _filterCategoryId = c.id),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: sorted.isEmpty
                      ? IllustratedEmptyState(
                          icon: Icons.filter_list_off_outlined,
                          title: 'Bu filtreyle eşleşme yok',
                          subtitle:
                              'Farklı bir kategori seçin ya da filtreyi kaldırın.',
                          actionLabel: 'Filtreyi temizle',
                          onAction: () => setState(() =>
                              _filterCategoryId = NewsCategory.all.id),
                        )
                      : _groupByCategory
                          ? _GroupedList(
                              articles: sorted,
                              onOpen: _openDetail,
                            )
                          : _FlatList(
                              articles: sorted,
                              onOpen: _openDetail,
                              dividerColor:
                                  cs.outlineVariant.withValues(alpha: 0.4),
                            ),
                ),
              ],
            ),
    );
  }

  static Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tümünü silmek istediğinize emin misiniz?'),
        content: const Text(
            'Kaydettiğiniz tüm haberler kaldırılacak. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<BookmarkProvider>().clearAll();
    }
  }
}

class _FlatList extends StatelessWidget {
  const _FlatList({
    required this.articles,
    required this.onOpen,
    required this.dividerColor,
  });

  final List<Article> articles;
  final ValueChanged<Article> onOpen;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: articles.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: dividerColor,
      ),
      itemBuilder: (context, index) {
        final a = articles[index];
        return _DismissibleBookmark(
          article: a,
          onTap: () => onOpen(a),
        );
      },
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.articles, required this.onOpen});

  final List<Article> articles;
  final ValueChanged<Article> onOpen;

  Map<NewsCategory, List<Article>> _groupByCategory() {
    final map = <NewsCategory, List<Article>>{};
    for (final a in articles) {
      map.putIfAbsent(a.category, () => []).add(a);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = _groupByCategory().entries.toList()
      ..sort((a, b) => a.key.name.compareTo(b.key.name));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final entry = groups[gi];
        final cat = entry.key;
        final items = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  Icon(cat.icon, size: 18, color: cat.color),
                  const SizedBox(width: 8),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cat.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final a in items)
              _DismissibleBookmark(
                article: a,
                onTap: () => onOpen(a),
              ),
          ],
        );
      },
    );
  }
}

class _DismissibleBookmark extends StatelessWidget {
  const _DismissibleBookmark({
    required this.article,
    required this.onTap,
  });

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('bookmark-${article.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: cs.onErrorContainer),
            const SizedBox(width: 6),
            Text(
              'Sil',
              style: TextStyle(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        final removed = article;
        context.read<BookmarkProvider>().remove(removed.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('"${removed.title}" listenizden çıkarıldı'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Geri al',
              onPressed: () =>
                  context.read<BookmarkProvider>().toggle(removed.id),
            ),
          ));
      },
      child: ArticleCard(article: article, onTap: onTap),
    );
  }
}
