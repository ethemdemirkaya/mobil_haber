import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_constants.dart';
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
import '../briefing/daily_briefing_screen.dart';
import '../category/category_articles_screen.dart';
import '../detail/article_detail_screen.dart';
import '../search/search_screen.dart';
import '../settings/source_preferences_screen.dart';

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
                        icon: Icons.podcasts_rounded,
                        tooltip: 'Sesli brifing',
                        accent: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DailyBriefingScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
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
              if (news.hasError)
                SliverToBoxAdapter(
                  child: ErrorBanner(
                    message: news.lastError ?? 'Bilinmeyen hata',
                    onRetry: _refresh,
                    onDismiss: () =>
                        context.read<NewsProvider>().clearError(),
                  ),
                )
              else if (news.usingFallback && !news.loading)
                SliverToBoxAdapter(
                  child: _OfflineFallbackNotice(onRetry: _refresh),
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
              if (news.trending(take: 6).isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Trend',
                    subtitle: 'En çok okunanlar',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: news.trending(take: 6).length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final a = news.trending(take: 6)[index];
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
                      onTap: () => _openArticle(
                        a,
                        heroTag: 'card-img-${a.id}',
                      ),
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
        // v2: "Editörün seçtikleri" yerine, agregatör konseptine uyumlu
        // "Öne çıkan başlıklar — son 24 saat".
        const SectionHeader(
          title: 'Öne çıkanlar',
          subtitle: 'Son güncel başlıklar',
        ),
        SizedBox(
          height: 248,
          child: PageView.builder(
            controller: controller,
            itemCount: articles.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, index) {
              final a = articles[index];
              final active = index == currentIndex;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  // Aktif kartın ölçeklenmesi yerine padding farkıyla
                  // hafif "yükseliyor" hissi.
                  vertical: active ? 4 : 16,
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  scale: active ? 1.0 : 0.97,
                  child: FeaturedArticleCard(
                    article: a,
                    onTap: () => onTap(a),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(articles.length, (i) {
            final selected = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.article,
    required this.rank,
    required this.onTap,
  });

  final Article article;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = article.category;
    return SizedBox(
      width: 280,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArticleImage(
                url: article.imageUrl,
                fit: BoxFit.cover,
                borderRadius: 18,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xCC000000),
                      Color(0xEE000000),
                    ],
                    stops: [0.0, 0.4, 0.8, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 13, color: cs.onPrimary),
                      const SizedBox(width: 4),
                      Text(
                        '#$rank',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
    final progress = context.select<ReadingProgressProvider, double>(
      (p) => p.get(article.id),
    );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
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
              // Okuma ilerleme çubuğu — en alt kenarda 3px ince çizgi.
              // Kullanıcının nerede kaldığını gösterir; pozitif geri
              // bildirim ve "geri dönüp tamamla" davetkârlığı sağlar.
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor:
                      cs.outlineVariant.withValues(alpha: 0.4),
                  valueColor:
                      AlwaysStoppedAnimation(article.category.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header'daki bildirim/aksiyon butonu — daha yumuşak yuvarlatılmış
/// sürüm.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Marka vurgulu varyant — sesli brifing gibi öne çıkartmak istediğimiz
  /// aksiyonlar için. Primary container rengiyle dolu pill gösterir.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = accent ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = accent ? cs.onPrimaryContainer : cs.onSurface;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Home ekranının üstünde duran arama kısayol bandı. Tek dokunuşla
/// SearchScreen'i route olarak açar (bottom-nav sekme switching'e
/// karşı: çağrı kalıcı bir route, kullanıcı geri tuşuyla dönebilir).
class _SearchShortcutBar extends StatelessWidget {
  const _SearchShortcutBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Haber, yazar veya kategori ara…',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aktif kaynak rozeti (logo + kısa ad). Üzerine dokunmak haber listesini
/// o kaynağa göre filtreliyor — şu an basit gösterim için pop-up.
class _SourceMiniCard extends StatelessWidget {
  const _SourceMiniCard({required this.source});

  final NewsSource source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: source.brandColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: source.brandColor.withValues(alpha: 0.10),
              ),
              child: CachedNetworkImage(
                imageUrl: source.logoUrl,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                placeholder: (_, _) => _LogoFallback(source: source),
                errorWidget: (_, _, _) => _LogoFallback(source: source),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            source.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.source});
  final NewsSource source;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      color: source.brandColor.withValues(alpha: 0.14),
      child: Text(
        source.shortName.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: source.brandColor,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _AddSourcesChip extends StatelessWidget {
  const _AddSourcesChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: cs.primary, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Düzenle',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
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

/// Aggregate başarısız + mock fallback aktif olduğunda gösterilen yumuşak
/// bilgi banner'ı (hata değil, durum bildirimi).
class _OfflineFallbackNotice extends StatelessWidget {
  const _OfflineFallbackNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Çevrimdışısınız — örnek veriler gösteriliyor.',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
  }
}
