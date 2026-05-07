import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/article_image.dart';
import '../../widgets/author_profile_sheet.dart';
import '../../widgets/section_header.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReadingHistoryProvider>().markRead(widget.article.id);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.position.pixels;
    final next = max <= 0 ? 0.0 : (offset / max).clamp(0.0, 1.0);
    if ((next - _progress).abs() > 0.005) {
      setState(() => _progress = next);
    }
  }

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    final a = widget.article;
    final text = '${a.title}\n\n${a.summary}\n\n— mobil_haber';
    await Share.share(text, subject: a.title);
  }

  void _openAuthor() {
    HapticFeedback.selectionClick();
    AuthorProfileSheet.show(context, widget.article.author).then((selected) {
      if (selected is Article && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArticleDetailScreen(article: selected),
          ),
        );
      }
    });
  }

  void _bumpFontScale(int delta) {
    final theme = context.read<ThemeProvider>();
    final order = AppFontScale.values;
    final current = order.indexOf(theme.fontScale);
    final next = (current + delta).clamp(0, order.length - 1);
    if (next == current) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    theme.setFontScale(order[next]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final article = widget.article;
    final cat = article.category;

    final related = context.select<NewsProvider, List<Article>>(
      (n) => n.related(article),
    );

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: cs.surface,
                foregroundColor: cs.onSurface,
                systemOverlayStyle: cs.brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                actions: [
                  IconButton(
                    tooltip: 'Yazı boyutu küçült',
                    icon: const Icon(Icons.text_decrease_outlined),
                    onPressed: () => _bumpFontScale(-1),
                  ),
                  IconButton(
                    tooltip: 'Yazı boyutu büyüt',
                    icon: const Icon(Icons.text_increase_outlined),
                    onPressed: () => _bumpFontScale(1),
                  ),
                  IconButton(
                    tooltip: 'Paylaş',
                    icon: const Icon(Icons.ios_share_outlined),
                    onPressed: _share,
                  ),
                  _BookmarkAction(article: article),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'article-img-${article.id}',
                        child: ArticleImage(
                          url: article.imageUrl,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 14, color: cat.color),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cat.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        article.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _openAuthor,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.primaryContainer
                                    .withValues(alpha: 0.7),
                                child: Text(
                                  _initials(article.author),
                                  style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(article.author,
                                        style: textTheme.titleSmall),
                                    Text(
                                      DateFormatter.full(
                                          article.publishedAt),
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule_outlined,
                                        size: 14,
                                        color: cs.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${article.readMinutes} dk',
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        article.summary,
                        style: textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(
                          height: 1,
                          color:
                              cs.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 18),
                      Text(
                        article.content,
                        style:
                            textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
              if (related.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'İlgili haberler'),
                ),
                SliverList.builder(
                  itemCount: related.length,
                  itemBuilder: (context, index) {
                    final r = related[index];
                    return _RelatedTile(article: r);
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
          // Üst kenardaki okuma ilerleme çubuğu (status bar altında).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _BookmarkAction extends StatelessWidget {
  const _BookmarkAction({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saved = context.select<BookmarkProvider, bool>(
      (b) => b.isBookmarked(article.id),
    );
    return IconButton(
      tooltip: saved ? 'Kayıttan çıkar' : 'Kaydet',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_outline,
          key: ValueKey(saved),
          color: saved ? cs.primary : null,
        ),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        context.read<BookmarkProvider>().toggle(article.id);
      },
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArticleImage(
                url: article.imageUrl,
                width: 88,
                height: 72,
                borderRadius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormatter.relative(article.publishedAt),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
