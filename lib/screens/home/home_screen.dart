import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../providers/news_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/article_image.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../category/category_articles_screen.dart';
import '../detail/article_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _featuredCtrl =
      PageController(viewportFraction: 0.88);
  int _featuredIndex = 0;
  Timer? _autoScrollTimer;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _featuredCtrl.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _userPaused) return;
      if (!_featuredCtrl.hasClients) return;
      final featured = context.read<NewsProvider>().featured;
      if (featured.length < 2) return;
      final next = (_featuredIndex + 1) % featured.length;
      _featuredCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _refresh() async {
    await context.read<NewsProvider>().refresh();
  }

  void _openArticle(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  void _openCategory(NewsCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryArticlesScreen(category: category),
      ),
    );
  }

  void _showLatestSheet() {
    final news = context.read<NewsProvider>();
    final latest = news.latest(take: 8);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Son haberler',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Anlık güncellemeler',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: latest.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final a = latest[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              a.category.color.withValues(alpha: 0.15),
                          child: Icon(a.category.icon,
                              color: a.category.color, size: 18),
                        ),
                        title: Text(
                          a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                            Text(DateFormatter.relative(a.publishedAt)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openArticle(a);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final news = context.watch<NewsProvider>();

    final history = context.watch<ReadingHistoryProvider>();
    final continueReading = history.ids
        .map(news.byId)
        .whereType<Article>()
        .take(8)
        .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Merhaba 👋',
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppConstants.appName,
                              style:
                                  textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cs.primaryContainer
                              .withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: cs.onPrimaryContainer,
                          ),
                          onPressed: _showLatestSheet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (news.hasError)
                SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: news.lastError ?? 'Bilinmeyen hata',
                    onRetry: _refresh,
                    onDismiss: () =>
                        context.read<NewsProvider>().clearError(),
                  ),
                ),
              SliverToBoxAdapter(
                child: news.loading && news.featured.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(0, 18, 0, 0),
                        child: FeaturedSkeleton(),
                      )
                    : Listener(
                        onPointerDown: (_) =>
                            setState(() => _userPaused = true),
                        onPointerUp: (_) {
                          // Kullanıcı dokunduktan kısa süre sonra otomatik
                          // kaymayı yeniden açıyoruz.
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              setState(() => _userPaused = false);
                            }
                          });
                        },
                        child: _FeaturedCarousel(
                          controller: _featuredCtrl,
                          articles: news.featured,
                          currentIndex: _featuredIndex,
                          onIndexChanged: (i) =>
                              setState(() => _featuredIndex = i),
                          onTap: _openArticle,
                        ),
                      ),
              ),
              if (continueReading.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Devam et',
                    subtitle: 'Son okuduklarınız',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: continueReading.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final a = continueReading[index];
                        return _ContinueCard(
                          article: a,
                          onTap: () => _openArticle(a),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Kategoriler'),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    itemCount: NewsCategory.values.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = NewsCategory.values[index];
                      return CategoryChip(
                        category: c,
                        selected:
                            news.selectedCategoryId == c.id,
                        onTap: () => context
                            .read<NewsProvider>()
                            .selectCategory(c.id),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: news.selectedCategoryId == NewsCategory.all.id
                      ? 'Son haberler'
                      : news.selectedCategory.name,
                  subtitle: news.selectedCategoryId ==
                          NewsCategory.all.id
                      ? 'Tüm kategorilerden seçtiklerimiz'
                      : '${news.articles.length} haber',
                  actionLabel:
                      news.selectedCategoryId == NewsCategory.all.id
                          ? null
                          : 'Tümünü gör',
                  onAction:
                      news.selectedCategoryId == NewsCategory.all.id
                          ? null
                          : () => _openCategory(news.selectedCategory),
                ),
              ),
              if (news.loading && news.articles.isEmpty)
                SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (_, _) =>
                      const ArticleCardSkeleton(),
                )
              else if (news.articles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Bu kategoride haber yok',
                    subtitle:
                        'Başka bir kategori seçin veya yenilemeyi deneyin.',
                  ),
                )
              else
                SliverList.separated(
                  itemCount: news.articles.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (context, index) {
                    final a = news.articles[index];
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
      ),
    );
  }
}

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({
    required this.controller,
    required this.articles,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onTap,
  });

  final PageController controller;
  final List<Article> articles;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final ValueChanged<Article> onTap;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SectionHeader(
          title: 'Öne çıkanlar',
          subtitle: 'Editörün seçtikleri',
        ),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: controller,
            itemCount: articles.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, index) {
              final a = articles[index];
              return AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: index == currentIndex ? 4 : 14,
                ),
                child: FeaturedArticleCard(
                  article: a,
                  onTap: () => onTap(a),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(articles.length, (i) {
            final selected = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.article,
    required this.onTap,
  });

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Material(
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ArticleImage(
                  url: article.imageUrl,
                  width: 64,
                  height: 64,
                  borderRadius: 12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        article.category.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: article.category.color,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
