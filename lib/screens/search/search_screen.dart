import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../providers/news_provider.dart';
import '../../providers/search_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/empty_state.dart';
import '../detail/article_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _filterCategoryId = NewsCategory.all.id;

  @override
  void initState() {
    super.initState();
    final initial = context.read<SearchProvider>().query;
    _controller.text = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    context.read<SearchProvider>().setQuery(value);
  }

  void _commit(String value) {
    context.read<SearchProvider>().commit(value);
  }

  void _useHistory(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    _setQuery(value);
    _focusNode.unfocus();
  }

  void _openArticle(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  List<Article> _filtered(List<Article> source, String query) {
    return source.where((a) {
      final matchesQuery = a.matchesQuery(query);
      final matchesCategory =
          _filterCategoryId == NewsCategory.all.id ||
              a.categoryId == _filterCategoryId;
      return matchesQuery && matchesCategory;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final search = context.watch<SearchProvider>();
    final news = context.watch<NewsProvider>();
    final query = search.query.trim();
    final results = query.isEmpty && _filterCategoryId == NewsCategory.all.id
        ? const <Article>[]
        : _filtered(news.latest(take: 9999), query);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      onChanged: _setQuery,
                      onSubmitted: _commit,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          color: cs.onSurfaceVariant,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _controller.clear();
                                  _setQuery('');
                                },
                              ),
                        hintText: 'Haber, yazar veya kategori ara…',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: NewsCategory.values.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final c = NewsCategory.values[index];
                  final selected = _filterCategoryId == c.id;
                  return FilterChip(
                    label: Text(c.name),
                    avatar: Icon(c.icon, size: 16),
                    selected: selected,
                    onSelected: (_) => setState(
                      () => _filterCategoryId = c.id,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: query.isEmpty &&
                      _filterCategoryId == NewsCategory.all.id
                  ? _SearchSuggestions(
                      history: search.history,
                      onHistoryTap: _useHistory,
                      onClearHistory: () =>
                          context.read<SearchProvider>().clearHistory(),
                      onRemoveHistory: (q) =>
                          context.read<SearchProvider>().removeFromHistory(q),
                    )
                  : results.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: 'Sonuç bulunamadı',
                          subtitle:
                              'Farklı kelimeler veya kategori deneyin.',
                          actionLabel: 'Filtreyi temizle',
                          onAction: () {
                            _controller.clear();
                            _setQuery('');
                            setState(() =>
                                _filterCategoryId = NewsCategory.all.id);
                          },
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: results.length + 1,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: cs.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 8, 20, 12),
                                child: Text(
                                  '${results.length} sonuç',
                                  style:
                                      textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            final a = results[index - 1];
                            return ArticleCard(
                              article: a,
                              onTap: () => _openArticle(a),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.history,
    required this.onHistoryTap,
    required this.onClearHistory,
    required this.onRemoveHistory,
  });

  final List<String> history;
  final ValueChanged<String> onHistoryTap;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onRemoveHistory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (history.isEmpty) {
      return EmptyState(
        icon: Icons.travel_explore_outlined,
        title: 'Aramaya başlayın',
        subtitle:
            'Yukarıdan kelime veya kategori seçerek istediğiniz haberi bulun.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Son aramalar',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClearHistory,
                child: const Text('Temizle'),
              ),
            ],
          ),
        ),
        for (final q in history)
          ListTile(
            leading: Icon(Icons.history, color: cs.onSurfaceVariant),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onRemoveHistory(q),
            ),
            onTap: () => onHistoryTap(q),
          ),
      ],
    );
  }
}
