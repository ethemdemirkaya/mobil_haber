import '../../widgets/editorial_art.dart';
import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/pusula_glyph.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/models/news_source.dart';
import '../../providers/news_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/reading_progress_provider.dart';
import '../../widgets/article_card.dart';
import '../../widgets/article_image.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/source_logo.dart';
import '../briefing/daily_briefing_screen.dart';
import '../category/category_articles_screen.dart';
import '../detail/article_detail_screen.dart';
import '../search/search_screen.dart';
import '../settings/source_preferences_screen.dart';

part 'widgets/home_cards.dart';
part 'widgets/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _featuredCtrl = PageController(viewportFraction: 0.88);
  final ScrollController _scrollController = ScrollController();
  int _featuredIndex = 0;

  /// Ana sayfadaki "Son haberler" listesinde gösterilen haber sayısı.
  /// Eskiden sona yaklaşınca 15'er otomatik artıyordu; 10 kaynakta ~80
  /// kartlık, sonu gelmeyen bir sayfa oluşuyordu. Ana sayfa bir özet;
  /// tamamı "Tümünü gör" ile kategori ekranında.
  static const int _homeListLimit = 15;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _featuredCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<NewsProvider>().refresh();
  }

  void _openArticle(Article article, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article, heroTag: heroTag),
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
                    const Icon(AppIcons.bellRinging),
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
                          backgroundColor: a.category.color.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(
                            a.category.icon,
                            color: a.category.color,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(DateFormatter.relative(a.publishedAt)),
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
    final trending = news.trending(take: 6);
    final feed = news.homeFeed;

    final history = context.watch<ReadingHistoryProvider>();
    final continueReading = history
        .articles(lookup: news.byId)
        .take(8)
        .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const PusulaGlyph(size: 34),
                                const SizedBox(width: 10),
                                Text(
                                  'Pusula',
                                  style: textTheme.headlineLarge?.copyWith(
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormatter.day(DateTime.now()),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _HeaderIconButton(
                        icon: AppIcons.bell,
                        tooltip: 'Son haberler',
                        onTap: _showLatestSheet,
                      ),
                    ],
                  ),
                ),
              ),
              // Yarı-pasif arama bandı (kullanıcı dokununca SearchScreen'e
              // benzer bir deneyim için MainNavigation'da sekme değişir).
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: _SearchShortcutBar(),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: NewsCategory.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final c = NewsCategory.values[index];
                      return CategoryChip(
                        category: c,
                        selected: news.selectedCategoryId == c.id,
                        onTap: () =>
                            context.read<NewsProvider>().selectCategory(c.id),
                      );
                    },
                  ),
                ),
              ),
              // ── Sesli Brifing CTA — öne çıkarılmış girişim kartı ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _DailyBriefingCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DailyBriefingScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              // First-run "AI hazır" tek seferlik bilgilendirme.
              // ignore: deprecated_member_use_from_same_package
              if (news.hasError)
                SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: news.lastError ?? 'Bilinmeyen hata',
                    onRetry: _refresh,
                    onDismiss: () => context.read<NewsProvider>().clearError(),
                  ),
                )
              else if (news.offline && !news.loading)
                SliverToBoxAdapter(
                  child: _OfflineNotice(
                    cachedAt: news.lastFetchAt,
                    onRetry: _refresh,
                  ),
                ),
              SliverToBoxAdapter(
                child: news.loading && news.featured.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(0, 18, 0, 0),
                        child: FeaturedSkeleton(),
                      )
                    : _FeaturedCarousel(
                        controller: _featuredCtrl,
                        articles: news.featured,
                        currentIndex: _featuredIndex,
                        onIndexChanged: (i) =>
                            setState(() => _featuredIndex = i),
                        onTap: (a) =>
                            _openArticle(a, heroTag: 'featured-img-${a.id}'),
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
              if (trending.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Gündem',
                    subtitle: 'Birden çok kaynağın şu an işlediği olaylar',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: trending.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final a = trending[index];
                        return _TrendingCard(
                          article: a,
                          rank: index + 1,
                          onTap: () => _openArticle(a),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (news.activeSources.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Kaynaklarınız',
                    subtitle:
                        '${news.activeSources.length} aktif kaynak — '
                        'düzenle',
                    actionLabel: 'Düzenle',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SourcePreferencesScreen(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: news.activeSources.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        if (index == news.activeSources.length) {
                          return _AddSourcesChip(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SourcePreferencesScreen(),
                              ),
                            ),
                          );
                        }
                        final s = news.activeSources[index];
                        return _SourceMiniCard(source: s);
                      },
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: news.selectedCategoryId == NewsCategory.all.id
                      ? 'Son haberler'
                      : news.selectedCategory.name,
                  subtitle: '${news.articles.length} haber',
                  actionLabel: 'Tümünü gör',
                  onAction: () => _openCategory(news.selectedCategory),
                ),
              ),
              if (news.loading && news.articles.isEmpty)
                SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (_, _) => const ArticleCardSkeleton(),
                )
              else if (news.unavailable && news.articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: AppIcons.wifiOff,
                    title: 'Haberlere ulaşılamadı',
                    subtitle:
                        'İnternet bağlantınızı kontrol edip '
                        'tekrar deneyin.',
                    actionLabel: 'Tekrar dene',
                    onAction: _refresh,
                  ),
                )
              else if (news.articles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: AppIcons.inbox,
                    title: 'Bu kategoride haber yok',
                    subtitle:
                        'Başka bir kategori seçin veya yenilemeyi deneyin.',
                  ),
                )
              else ...[
                SliverList.separated(
                  itemCount: feed.length.clamp(0, _homeListLimit),
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (context, index) {
                    final a = feed[index];
                    return ArticleCard(
                      article: a,
                      onTap: () => _openArticle(a, heroTag: 'card-img-${a.id}'),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: _SeeAllFooter(
                    shown: feed.length.clamp(0, _homeListLimit),
                    total: news.articles.length,
                    onSeeAll: () => _openCategory(news.selectedCategory),
                    onRefresh: _refresh,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
