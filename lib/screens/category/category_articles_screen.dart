import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/category.dart';
import '../../providers/news_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/empty_state.dart';
import '../detail/article_detail_screen.dart';

class CategoryArticlesScreen extends StatelessWidget {
  const CategoryArticlesScreen({super.key, required this.category});

  final NewsCategory category;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final articles = context.select<NewsProvider, List<dynamic>>(
      (n) => n.articlesOf(category.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(category.icon, color: category.color),
            const SizedBox(width: 8),
            Text(category.name),
          ],
        ),
      ),
      body: articles.isEmpty
          ? EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Henüz haber yok',
              subtitle: '${category.name} kategorisinde gösterilecek haber bulunamadı.',
            )
          : ListView.separated(
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
                        builder: (_) => ArticleDetailScreen(article: a),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
