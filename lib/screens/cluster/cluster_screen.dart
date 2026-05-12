import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/repositories/news_cluster_service.dart';
import '../../providers/news_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/source_logo.dart';
import '../../data/models/news_source.dart';
import '../detail/article_detail_screen.dart';

/// Çapraz Kaynak Bakış — projenin TÜBİTAK için öne çıkan ana özelliği.
///
/// Aynı olayı haber yapan **farklı kaynakları** otomatik gruplar ve
/// kullanıcıya yan yana manşet seçimini gösterir. Böylece kullanıcı
/// tek olayın 5 farklı medyada nasıl çerçevelendiğini görür.
class ClusterScreen extends StatefulWidget {
  const ClusterScreen({super.key});

  @override
  State<ClusterScreen> createState() => _ClusterScreenState();
}

class _ClusterScreenState extends State<ClusterScreen> {
  final NewsClusterService _service = NewsClusterService();

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final clusters = _service.findClusters(news.articles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çapraz Bakış'),
        actions: [
          IconButton(
            tooltip: 'Bilgi',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<NewsProvider>().refresh(),
        child: clusters.isEmpty
            ? const _EmptyClusterState()
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _IntroBanner(count: clusters.length),
                  ),
                  SliverList.separated(
                    itemCount: clusters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = clusters[index];
                      return _ClusterCard(
                        cluster: c,
                        onArticleTap: (a) => _open(a),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }

  void _open(Article a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: a),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub, color: cs.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Çapraz Kaynak Bakış',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Aynı olayı haber yapan farklı kaynakları otomatik '
                  'gruplandırır. Türkçe-aware token bazlı Jaccard benzerliği '
                  've 36 saatlik zaman penceresi ile çalışır.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Neden önemli?',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bir olayın 5 farklı medyada nasıl çerçevelendiğini yan '
                  'yana görerek **medya çoğulluğunu** ve **manşet seçim '
                  'farklarını** keşfedebilirsiniz. Bu özellik, hem medya '
                  'okuryazarlığını hem de bilinçli haber tüketimini '
                  'destekler.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16, color: cs.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tüm hesaplama cihazınızda yapılır — hiçbir '
                          'veri sunucuya gitmez.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.55),
            cs.primaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hub, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count farklı olay tespit edildi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Her olayı haber yapan kaynakları yan yana karşılaştırın',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({
    required this.cluster,
    required this.onArticleTap,
  });

  final NewsCluster cluster;
  final ValueChanged<Article> onArticleTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = NewsCategory.byId(cluster.dominantCategoryId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 13, color: cat.color),
                      const SizedBox(width: 4),
                      Text(
                        cat.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cat.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 12, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${cluster.sourceCount} kaynak',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormatter.relative(cluster.latestAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              cluster.headline,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.3,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Text(
              'Aynı olay, farklı manşetler:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            itemCount: cluster.articles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final a = cluster.articles[index];
              return _ClusterMemberTile(
                article: a,
                onTap: () => onArticleTap(a),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClusterMemberTile extends StatelessWidget {
  const _ClusterMemberTile({
    required this.article,
    required this.onTap,
  });

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = NewsSourceCatalog.all.firstWhere(
      (s) => s.name == article.sourceName,
      orElse: () => NewsSource(
        id: 'unknown',
        name: article.sourceName,
        shortName: article.sourceName,
        tagline: '',
        domain: '',
        brandColor: cs.primary,
        primaryFeed: '',
      ),
    );
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SourceLogo(source: source, size: 28, borderRadius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.shortName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: source.brandColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClusterState extends StatelessWidget {
  const _EmptyClusterState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        EmptyState(
          icon: Icons.hub_outlined,
          title: 'Henüz çapraz olay yok',
          subtitle: 'Daha fazla kaynak aktifken aynı olayı haber yapan '
              'kaynaklar otomatik gruplanır. Yeniliyoruz...',
        ),
      ],
    );
  }
}
