import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/article.dart';
import '../../data/repositories/external_news_repository.dart';
import '../../providers/external_news_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../../widgets/shimmer_loading.dart';
import '../detail/article_detail_screen.dart';

class LiveNewsScreen extends StatefulWidget {
  const LiveNewsScreen({super.key});

  @override
  State<LiveNewsScreen> createState() => _LiveNewsScreenState();
}

class _LiveNewsScreenState extends State<LiveNewsScreen> {
  bool _aggregateMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ExternalNewsProvider>();
      if (p.sources.isEmpty) {
        p.loadSources().then((_) {
          if (mounted && p.selectedSourceId != null) {
            p.loadArticles();
          }
        });
      }
    });
  }

  Future<void> _refresh() async {
    final p = context.read<ExternalNewsProvider>();
    if (_aggregateMode) {
      await p.loadAggregated();
    } else {
      await p.loadArticles();
    }
  }

  void _toggleAggregate() {
    setState(() => _aggregateMode = !_aggregateMode);
    final p = context.read<ExternalNewsProvider>();
    if (_aggregateMode) {
      p.loadAggregated();
    } else if (p.selectedSourceId != null) {
      p.loadArticles();
    }
  }

  void _openArticle(Article a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: a),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = context.watch<ExternalNewsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı Haberler'),
        actions: [
          IconButton(
            tooltip:
                _aggregateMode ? 'Tek kaynağa geç' : 'Tüm kaynakları birleştir',
            icon: Icon(
              _aggregateMode ? Icons.filter_alt : Icons.merge_type,
            ),
            onPressed: _toggleAggregate,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (p.error != null)
              SliverToBoxAdapter(
                child: ErrorBanner(
                  message: p.error!,
                  onRetry: _refresh,
                  onDismiss: () =>
                      context.read<ExternalNewsProvider>().clearError(),
                ),
              ),
            if (!_aggregateMode)
              SliverToBoxAdapter(
                child: _SourceChipsRow(
                  sources: p.sources,
                  loading: p.loadingSources,
                  selectedId: p.selectedSourceId,
                  onSelect: (id) => context
                      .read<ExternalNewsProvider>()
                      .selectSource(id),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.sensors, color: cs.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _aggregateMode
                          ? 'Tüm kaynaklardan birleştirilmiş'
                          : (p.selectedSource?.name ?? 'Kaynak seçin'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (p.articles.isNotEmpty)
                      Text(
                        '${p.articles.length} haber',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            if (p.loadingArticles && p.articles.isEmpty)
              SliverList.builder(
                itemCount: 5,
                itemBuilder: (_, _) => const ArticleCardSkeleton(),
              )
            else if (p.articles.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: IllustratedEmptyState(
                  icon: Icons.podcasts_outlined,
                  title: 'Henüz haber yok',
                  subtitle:
                      'Bir kaynak seçin veya birleştir moduna geçin. Aşağı çekerek yenileyin.',
                ),
              )
            else
              SliverList.separated(
                itemCount: p.articles.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final a = p.articles[index];
                  return ArticleCard(
                    article: a,
                    onTap: () => _openArticle(a),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SourceChipsRow extends StatelessWidget {
  const _SourceChipsRow({
    required this.sources,
    required this.loading,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ExternalSource> sources;
  final bool loading;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading && sources.isEmpty) {
      return SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, _) => const ShimmerBox(
            width: 110,
            height: 36,
            borderRadius: 18,
          ),
        ),
      );
    }
    if (sources.isEmpty) return const SizedBox(height: 8);

    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: sources.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = sources[i];
          final selected = s.id == selectedId;
          final disabled = !s.available;
          return Opacity(
            opacity: disabled ? 0.45 : 1.0,
            child: ChoiceChip(
              label: Text(
                s.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
              avatar: Icon(
                disabled
                    ? Icons.lock_outline
                    : (s.requiresApiKey
                        ? Icons.vpn_key_outlined
                        : Icons.rss_feed),
                size: 16,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              selected: selected,
              onSelected: disabled ? null : (_) => onSelect(s.id),
              selectedColor: cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }
}
