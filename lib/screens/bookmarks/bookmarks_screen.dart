import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/empty_state.dart';
import '../detail/article_detail_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookmarks = context.watch<BookmarkProvider>();
    final news = context.watch<NewsProvider>();

    final saved = bookmarks.ids
        .map((id) => news.byId(id))
        .whereType<Article>()
        .toList(growable: false)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydedilenler'),
        actions: [
          if (saved.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearAll(context),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Tümünü sil'),
            ),
        ],
      ),
      body: saved.isEmpty
          ? EmptyState(
              icon: Icons.bookmark_outline,
              title: 'Henüz haber kaydetmediniz',
              subtitle:
                  'Beğendiğiniz haberleri kaydedip dilediğiniz an buradan okuyabilirsiniz.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: saved.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              itemBuilder: (context, index) {
                final a = saved[index];
                return Dismissible(
                  key: ValueKey('bookmark-${a.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: cs.errorContainer,
                    alignment: Alignment.centerRight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.delete_outline,
                            color: cs.onErrorContainer),
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
                    final removed = a;
                    context
                        .read<BookmarkProvider>()
                        .remove(removed.id);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(
                            '"${removed.title}" listenizden çıkarıldı'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Geri al',
                          onPressed: () => context
                              .read<BookmarkProvider>()
                              .toggle(removed.id),
                        ),
                      ));
                  },
                  child: ArticleCard(
                    article: a,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ArticleDetailScreen(article: a),
                        ),
                      );
                    },
                  ),
                );
              },
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
