import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../data/models/category.dart';
import '../../data/models/news_source.dart';
import '../../providers/ai_settings_provider.dart';
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
  final PageController _featuredCtrl =
      PageController(viewportFraction: 0.88);
  final ScrollController _scrollController = ScrollController();
  int _featuredIndex = 0;
  Timer? _autoScrollTimer;
  bool _userPaused = false;

  /// İlk açılışta liste içinde görünen makale sayısı. Kullanıcı sona
  /// yaklaştığında `_loadMoreStep` kadar artar — pseudo-pagination.
  int _visibleCount = _initialVisible;
  static const int _initialVisible = 15;
  static const int _loadMoreStep = 15;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _featuredCtrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Sona ~600px kala bir sonraki batch'i göster. Yeni HTTP yok —
  /// NewsProvider zaten tüm makaleleri çekti, biz görünür kısmı artırıyoruz.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      final news = context.read<NewsProvider>();
      final total = news.articles.length;
      if (_visibleCount < total) {
        setState(() {
          _visibleCount = (_visibleCount + _loadMoreStep).clamp(0, total);
        });
      }
    }
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

  void _openArticle(Article article, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(
          article: article,
          heroTag: heroTag,
        ),
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
    final trending = news.trending(take: 6);

    final history = context.watch<ReadingHistoryProvider>();
    final continueReading =
        history.articles(lookup: news.byId).take(8).toList(growable: false);

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
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  AppConstants.appName,
                                  style:
                                      textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // v2 (özetleyici) marka rozetimsi vurgu
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primary
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'özet',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hızlı · Birleştirilmiş · Özet',
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HeaderIconButton(
                        icon: Icons.notifications_none_rounded,
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
                  padding:
                      const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: _SearchShortcutBar(),
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
              const SliverToBoxAdapter(child: _AiReadyBanner()),
              if (news.hasError)
                SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: news.lastError ?? 'Bilinmeyen hata',
                    onRetry: _refresh,
                    onDismiss: () =>
                        context.read<NewsProvider>().clearError(),
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
                          onTap: (a) => _openArticle(
                            a,
                            heroTag: 'featured-img-${a.id}',
                          ),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: trending.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 12),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: news.activeSources.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        if (index == news.activeSources.length) {
                          return _AddSourcesChip(
                            onTap: () =>
                                Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SourcePreferencesScreen(),
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
              else if (news.unavailable && news.articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Haberlere ulaşılamadı',
                    subtitle: 'İnternet bağlantınızı kontrol edip '
                        'tekrar deneyin.',
                    actionLabel: 'Tekrar dene',
                    onAction: _refresh,
                  ),
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
              else ...[
                SliverList.separated(
                  itemCount:
                      news.articles.length.clamp(0, _visibleCount),
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
                      onTap: () => _openArticle(
                        a,
                        heroTag: 'card-img-${a.id}',
                      ),
                    );
                  },
                ),
                // "Daha fazla yükle" footer — scroll auto-load çalışıyor
                // ama görsel olarak da gösterip butonla manuel tetiklemeye
                // izin verelim. Liste sonuna gelindiyse "Hepsi bu kadar".
                SliverToBoxAdapter(
                  child: _LoadMoreFooter(
                    visible: _visibleCount,
                    total: news.articles.length,
                    onLoadMore: () => setState(() {
                      _visibleCount = (_visibleCount + _loadMoreStep)
                          .clamp(0, news.articles.length);
                    }),
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
