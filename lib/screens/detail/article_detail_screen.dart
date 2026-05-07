import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/article.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/reading_progress_provider.dart';
import '../../providers/reading_theme_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/article_image.dart';
import '../../widgets/author_profile_sheet.dart';
import '../../widgets/section_header.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.heroTag,
  });

  final Article article;

  /// Çağıran widget'ın Hero tag'i. Null ise hero animasyonu çalışmaz
  /// (basit page transition'a düşer). Aynı haber home ekranında birden
  /// fazla kart varyasyonunda görünebildiği için her çağıran kendi
  /// prefix'iyle bunu belirtir.
  final String? heroTag;

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
      _restoreScrollPosition();
    });
  }

  void _restoreScrollPosition() {
    if (!_scrollController.hasClients) return;
    final saved = context
        .read<ReadingProgressProvider>()
        .get(widget.article.id);
    if (saved <= 0.02 || saved >= 0.95) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      // Sayfa daha render olmamış, bir frame daha bekle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final m2 = _scrollController.position.maxScrollExtent;
        if (m2 > 0) {
          _scrollController.jumpTo(m2 * saved);
          setState(() => _progress = saved);
        }
      });
      return;
    }
    _scrollController.jumpTo(max * saved);
    setState(() => _progress = saved);
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
      // Scroll konumunu kalıcı kaydet.
      context.read<ReadingProgressProvider>().set(widget.article.id, next);
    }
  }

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    final a = widget.article;
    final url = a.hasOriginalUrl ? '\n${a.sourceUrl}' : '';
    final text = '${a.title}\n\n${a.summary}$url\n\n— mobil_haber';
    await Share.share(text, subject: a.title);
  }

  Future<void> _openOriginal(String url) async {
    if (url.isEmpty) return;
    HapticFeedback.selectionClick();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Bağlantı açılamadı'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Future<void> _openAuthor() async {
    HapticFeedback.selectionClick();
    final selected =
        await AuthorProfileSheet.show(context, widget.article.author);
    if (selected != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: selected),
        ),
      );
    }
  }

  /// Yazı boyutu + sepia okuma modu seçeneklerini tek bir popup'ta toplar.
  /// Detay ekranında 6 farklı action ikonu (geri + tema + A- + A+ + paylaş +
  /// kaydet) yan yana fotoğrafa karışıyordu; artık 4 (geri + Aa + paylaş +
  /// kaydet) butonla daha temiz görünüyor.
  void _showReadingOptions() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Okuma seçenekleri',
                      style:
                          Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Yazı boyutu',
                  style: Theme.of(sheetCtx).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                ),
                const SizedBox(height: 8),
                Consumer<ThemeProvider>(
                  builder: (_, t, _) => SegmentedButton<AppFontScale>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppFontScale.small,
                        label: Text('Küçük',
                            style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: AppFontScale.medium,
                        label: Text('Orta'),
                      ),
                      ButtonSegment(
                        value: AppFontScale.large,
                        label: Text('Büyük',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ],
                    selected: {t.fontScale},
                    onSelectionChanged: (set) {
                      HapticFeedback.selectionClick();
                      context
                          .read<ThemeProvider>()
                          .setFontScale(set.first);
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Okuma modu',
                  style: Theme.of(sheetCtx).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                ),
                const SizedBox(height: 8),
                Consumer<ReadingThemeProvider>(
                  builder: (_, r, _) => SegmentedButton<ReadingMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ReadingMode.normal,
                        icon: Icon(Icons.brightness_5, size: 16),
                        label: Text('Standart'),
                      ),
                      ButtonSegment(
                        value: ReadingMode.sepia,
                        icon: Icon(Icons.menu_book_outlined, size: 16),
                        label: Text('Sepya'),
                      ),
                    ],
                    selected: {r.readingMode},
                    onSelectionChanged: (set) {
                      HapticFeedback.selectionClick();
                      context
                          .read<ReadingThemeProvider>()
                          .setReadingMode(set.first);
                    },
                  ),
                ),
                const SizedBox(height: 8),
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
    final article = widget.article;
    final cat = article.category;

    final related = context.select<NewsProvider, List<Article>>(
      (n) => n.related(article),
    );
    final readingMode = context.watch<ReadingThemeProvider>();
    final isSepia = readingMode.isSepia;

    // Sepia palet — kremrengi arkaplan, sıcak ton metinler.
    const sepiaBg = Color(0xFFF5ECD7);
    const sepiaText = Color(0xFF3E2F1B);

    return Scaffold(
      backgroundColor: isSepia ? sepiaBg : null,
      // Sticky CTA: harici URL varsa her makalede alt kenarda görünür.
      // Önemli UX: kullanıcı uzun bir özeti okuyup geri scroll etmek
      // zorunda kalmadan kaynağa atlayabilir.
      bottomNavigationBar: article.hasOriginalUrl
          ? _OriginalLinkCta(
              accent: cat.color,
              host: _hostOf(article.sourceUrl),
              onPressed: () => _openOriginal(article.sourceUrl),
            )
          : null,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                // Saydam zemin + scrim buton tasarımı: hero görsel üstünde
                // gezinirken status bar'a karşı kontrast scrim'den geliyor.
                // Pin olduğunda da pill butonlar nötr görünüyor.
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                  child: _ScrimIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Geri',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _ScrimIconButton(
                      icon: Icons.text_fields_rounded,
                      tooltip: 'Okuma seçenekleri',
                      onTap: _showReadingOptions,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _ScrimIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'Paylaş',
                      onTap: _share,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 0, right: 12, top: 6, bottom: 6),
                    child: _BookmarkAction(article: article),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Hero yalnızca çağıran tag bildirdiyse aktif (aksi
                      // halde duplicate-tag hatası riskine girmemek için
                      // basit ImageContainer).
                      if (widget.heroTag != null)
                        Hero(
                          tag: widget.heroTag!,
                          child: ArticleImage(
                            url: article.imageUrl,
                            borderRadius: 0,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        ArticleImage(
                          url: article.imageUrl,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                        ),
                      // Üst scrim daha güçlü — pill butonların altındaki
                      // fotoğraf desenine bağlı kalmadan kontrast versin.
                      // Alt scrim içerik bölgesine yumuşak geçiş.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xB3000000),
                              Color(0x66000000),
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                            stops: [0.0, 0.22, 0.55, 1.0],
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
                        // v2: 800 → 700, daha rafine letter spacing.
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.22,
                          letterSpacing: -0.4,
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
                                    Icon(Icons.bolt_outlined,
                                        size: 14,
                                        color: cs.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${article.readMinutes} dk özet',
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
                      // Özet header
                      Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 16, color: cat.color),
                          const SizedBox(width: 6),
                          Text(
                            'ÖZET',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: cat.color,
                            ),
                          ),
                          const Spacer(),
                          if (article.sourceName.isNotEmpty)
                            Text(
                              article.sourceName,
                              style: textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Ana özet — büyük, okunaklı
                      Text(
                        article.summary.isNotEmpty
                            ? article.summary
                            : article.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: isSepia ? sepiaText : cs.onSurface,
                          fontWeight: FontWeight.w500,
                          height: isSepia ? 1.65 : 1.55,
                          fontSize: 17,
                          fontFamily: isSepia ? 'serif' : null,
                        ),
                      ),
                      // Eğer içerik özetten anlamlı şekilde uzunsa, ek
                      // bağlam olarak göster.
                      if (article.content.isNotEmpty &&
                          article.content != article.summary &&
                          article.content.length > article.summary.length + 80) ...[
                        const SizedBox(height: 14),
                        Text(
                          article.content,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isSepia
                                ? sepiaText.withValues(alpha: 0.85)
                                : cs.onSurfaceVariant,
                            height: isSepia ? 1.65 : 1.55,
                            fontFamily: isSepia ? 'serif' : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // CTA artık sticky alt kenarda — burada yalnızca
                      // harici kaynak yoksa bilgi rozeti gösteriliyor.
                      if (!article.hasOriginalUrl)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: cs.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bu özet için harici kaynak bağlantısı yok.',
                                  style: textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!article.hasOriginalUrl) const SizedBox(height: 12),
                      Text(
                        article.sourceName.isNotEmpty
                            ? 'Bu özet ${article.sourceName} tarafından sağlanan '
                                'metinden derlenmiştir; tam habere erişmek için '
                                'yukarıdaki butonu kullanın.'
                            : 'Özetler kaynak sağlayıcının sunduğu metinden '
                                'derlenir; tam habere erişmek için yukarıdaki '
                                'butonu kullanın.',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
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

  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final h = uri.host;
    return h.startsWith('www.') ? h.substring(4) : h;
  }
}

/// Detay ekranının alt kenarındaki sticky "Orijinali oku" CTA'sı.
class _OriginalLinkCta extends StatelessWidget {
  const _OriginalLinkCta({
    required this.accent,
    required this.host,
    required this.onPressed,
  });

  final Color accent;
  final String host;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.open_in_new, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Orijinal haberi oku',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (host.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    host,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkAction extends StatelessWidget {
  const _BookmarkAction({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<BookmarkProvider, bool>(
      (b) => b.isBookmarked(article.id),
    );
    return _ScrimIconButton(
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
      tooltip: saved ? 'Kayıttan çıkar' : 'Kaydet',
      activeAccent: saved,
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<BookmarkProvider>().toggle(article.id);
      },
    );
  }
}

/// Detay ekranının üst köşelerinde, fotoğraf üstünde duran action butonu.
///
/// Tek scrim renkli pill: dark blur arkaplan + beyaz icon. SliverAppBar
/// hem expand'de (resim arkada) hem collapsed'de (surface arkada) iyi
/// kontrast sağlıyor — koyu pill her ikisinde de ayırt edilebilir.
class _ScrimIconButton extends StatelessWidget {
  const _ScrimIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.activeAccent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool activeAccent;

  @override
  Widget build(BuildContext context) {
    final bg = activeAccent
        ? Colors.white
        : Colors.black.withValues(alpha: 0.42);
    final fg = activeAccent ? Colors.black : Colors.white;
    final button = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 18,
              color: fg,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
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
