import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../providers/news_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../detail/article_detail_screen.dart';

class ReadingHistoryScreen extends StatelessWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final history = context.watch<ReadingHistoryProvider>();
    final news = context.watch<NewsProvider>();

    final items = history.ids
        .map(news.byId)
        .whereType<Article>()
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Okuma Geçmişi'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Geçmişi temizle',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Geçmişi temizle'),
                    content: const Text(
                        'Tüm okuma geçmişiniz silinecek. Bu işlem geri alınamaz.'),
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
                  await context.read<ReadingHistoryProvider>().clear();
                }
              },
            ),
        ],
      ),
      body: items.isEmpty
          ? IllustratedEmptyState(
              icon: Icons.history,
              title: 'Henüz haber okumadınız',
              subtitle:
                  'Okuduğunuz haberler burada listelenir; "Devam et" satırına da yansır.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              itemBuilder: (context, i) {
                final a = items[i];
                return Dismissible(
                  key: ValueKey('history-${a.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: cs.errorContainer,
                    alignment: Alignment.centerRight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(Icons.delete_outline,
                        color: cs.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    context
                        .read<ReadingHistoryProvider>()
                        .remove(a.id);
                  },
                  child: ArticleCard(
                    article: a,
                    showBookmark: false,
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
                  ),
                );
              },
            ),
    );
  }
}
