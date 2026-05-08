import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/news_source.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/pusula_glyph.dart';
import '../main_navigation.dart';
import 'source_picker_screen.dart';

/// Pusula onboarding — uygulamanın geri kalanı ile aynı tema dilinde.
///
/// Tasarım:
///   - Tek consistent surface arka planı (theme.surface) — her sayfada
///     renk değişmez. Yerine sayfanın kendi accent rengi illustration
///     içinde belirir.
///   - Üstte minimal brand bar: Pusula glyph mini + "Atla".
///   - Merkez: 320×320 illustration card (custom painter) + başlık + alt
///     başlık + 3 highlight pill.
///   - Bottom: dot indicator (active = brand), CTA butonu (filledTonal →
///     son sayfada filled), "01 / 03" sayfa numarası.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.illustration,
    required this.highlights,
  });

  final String title;
  final String subtitle;

  /// Sayfa için accent renk — illustration ve dot indicator vurgusu.
  /// Tema brand rengi yerine kategorik vurgu — her sayfa farklı bir
  /// "anahtar kelime" hissi taşır.
  final Color accent;

  final _OnboardingIllustration illustration;
  final List<_HighlightChipData> highlights;
}

enum _OnboardingIllustration { layeredFeeds, lightningSummary, savedAndTuned }

class _HighlightChipData {
  const _HighlightChipData(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: 'Tüm haberler\ntek bir akışta',
      subtitle:
          '27+ kaynaktan gelen başlıkları birleştirir, çoklu yayınları aynı '
          'olay altında gruplarız. Tek bir akış — yine de her perspektif.',
      accent: Color(0xFFE5484D), // brand seed
      illustration: _OnboardingIllustration.layeredFeeds,
      highlights: [
        _HighlightChipData(Icons.layers_outlined, '27+ kaynak'),
        _HighlightChipData(Icons.hub_outlined, 'Çapraz bakış'),
        _HighlightChipData(Icons.local_fire_department_outlined, 'Gündem'),
      ],
    ),
    _OnboardingPageData(
      title: 'Yapay zekayla\nhızlıca anla',
      subtitle:
          'Uzun haberleri 3 maddede özetleriz. Sesli brifing ile 5 dakikada '
          'günü dinle, detayda kal.',
      accent: Color(0xFF1565C0),
      illustration: _OnboardingIllustration.lightningSummary,
      highlights: [
        _HighlightChipData(Icons.auto_awesome_outlined, 'AI özet'),
        _HighlightChipData(Icons.podcasts_rounded, 'Sesli brifing'),
        _HighlightChipData(Icons.chat_bubble_outline, 'Soru sor'),
      ],
    ),
    _OnboardingPageData(
      title: 'Sana özel,\nelinin altında',
      subtitle:
          'İlgi alanına göre kişisel akış, anahtar kelime filtreleri ve '
          'kayıt listesi. Hiçbir haberi kaçırma.',
      accent: Color(0xFF6A1B9A),
      illustration: _OnboardingIllustration.savedAndTuned,
      highlights: [
        _HighlightChipData(Icons.tune_outlined, 'Kişiselleştir'),
        _HighlightChipData(Icons.bookmark_added_outlined, 'Kaydet'),
        _HighlightChipData(Icons.search_rounded, 'Anahtar kelime'),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Atla" — kullanıcı önerilen kaynaklarla MainNavigation'a düşer.
  Future<void> _skip() async {
    HapticFeedback.lightImpact();
    final prefs = context.read<PreferencesProvider>();
    final news = context.read<NewsProvider>();
    final onboarding = context.read<OnboardingProvider>();
    if (prefs.selectedSources.isEmpty) {
      await prefs.setSelectedSources(
        NewsSourceCatalog.recommendedIds.toSet(),
      );
    }
    await onboarding.complete();
    if (!mounted) return;
    // ignore: unawaited_futures
    news.applySources(prefs.effectiveSources);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const MainNavigation(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _continueToPicker() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => const SourcePickerScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index >= _pages.length - 1) {
      _continueToPicker();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final last = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: cs.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
        child: SafeArea(
          child: Column(
            children: [
              _BrandBar(onSkip: last ? null : _skip),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _index = i);
                  },
                  itemBuilder: (context, i) {
                    return _OnboardingPage(
                      data: _pages[i],
                      // Page transition'a senkronize fade — komşu sayfalar
                      // arası geçişte content soft fade alır.
                      isActive: i == _index,
                    );
                  },
                ),
              ),
              _BottomBar(
                pageIndex: _index,
                pageCount: _pages.length,
                accent: _pages[_index].accent,
                onNext: _next,
                onSelectAccent: (i) {
                  HapticFeedback.selectionClick();
                  _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                ctaLabel: last ? 'Kaynakları seç' : 'Devam',
                isLast: last,
              ),
              SizedBox(height: 8 + MediaQuery.of(context).padding.bottom * 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar({required this.onSkip});
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          // Mini glyph + wordmark — splash → onboarding kontinüite.
          PusulaGlyph(
            size: 28,
            showRim: false,
            foreground: cs.primary,
            background: cs.surface,
            muted: cs.onSurfaceVariant,
            accent: cs.outline,
          ),
          const SizedBox(width: 10),
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: const Text('Atla'),
            )
          else
            const SizedBox(height: 36),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.isActive});
  final _OnboardingPageData data;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  scale: isActive ? 1.0 : 0.94,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: isActive ? 1.0 : 0.6,
                    child: _IllustrationCard(
                      kind: data.illustration,
                      accent: data.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sayfa accent renginde minik etiket — "anahtar kelime".
                _AccentTag(accent: data.accent, label: _eyebrow(data)),
                const SizedBox(height: 12),
                Text(
                  data.title,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.6,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.subtitle,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in data.highlights)
                      _HighlightChip(
                        data: h,
                        accent: data.accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _eyebrow(_OnboardingPageData d) {
    switch (d.illustration) {
      case _OnboardingIllustration.layeredFeeds:
        return 'AKIŞ';
      case _OnboardingIllustration.lightningSummary:
        return 'HIZ';
      case _OnboardingIllustration.savedAndTuned:
        return 'KİŞİSEL';
    }
  }
}

class _AccentTag extends StatelessWidget {
  const _AccentTag({required this.accent, required this.label});
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accent.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.data, required this.accent});
  final _HighlightChipData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.kind, required this.accent});
  final _OnboardingIllustration kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft accent halo arka planda.
          Positioned.fill(
            child: CustomPaint(
              painter: _AccentHaloPainter(
                accent: accent,
                isDark: isDark,
              ),
            ),
          ),
          // Asıl illustration painter.
          Padding(
            padding: const EdgeInsets.all(18),
            child: CustomPaint(
              painter: _resolvePainter(kind, accent, cs, isDark),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  CustomPainter _resolvePainter(
    _OnboardingIllustration kind,
    Color accent,
    ColorScheme cs,
    bool isDark,
  ) {
    switch (kind) {
      case _OnboardingIllustration.layeredFeeds:
        return _LayeredFeedsPainter(
          accent: accent,
          surface: cs.surface,
          fg: cs.onSurface,
          muted: cs.onSurfaceVariant,
          outline: cs.outlineVariant,
          isDark: isDark,
        );
      case _OnboardingIllustration.lightningSummary:
        return _LightningSummaryPainter(
          accent: accent,
          surface: cs.surface,
          fg: cs.onSurface,
          muted: cs.onSurfaceVariant,
          outline: cs.outlineVariant,
          isDark: isDark,
        );
      case _OnboardingIllustration.savedAndTuned:
        return _SavedAndTunedPainter(
          accent: accent,
          surface: cs.surface,
          fg: cs.onSurface,
          muted: cs.onSurfaceVariant,
          outline: cs.outlineVariant,
          isDark: isDark,
        );
    }
  }
}

/// Accent renkli yumuşak köşegen halo arka plan.
class _AccentHaloPainter extends CustomPainter {
  _AccentHaloPainter({required this.accent, required this.isDark});
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.6),
        radius: 1.1,
        colors: [
          accent.withValues(alpha: isDark ? 0.20 : 0.14),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, 0.8),
        radius: 0.9,
        colors: [
          accent.withValues(alpha: isDark ? 0.10 : 0.06),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint2);
  }

  @override
  bool shouldRepaint(covariant _AccentHaloPainter old) =>
      old.accent != accent || old.isDark != isDark;
}

// ───────────────────────── Sayfa Illustrasyonları ─────────────────────────

abstract class _BasePagePainter extends CustomPainter {
  _BasePagePainter({
    required this.accent,
    required this.surface,
    required this.fg,
    required this.muted,
    required this.outline,
    required this.isDark,
  });

  final Color accent;
  final Color surface;
  final Color fg;
  final Color muted;
  final Color outline;
  final bool isDark;

  /// Mini haber kartı çizici — istif görünümleri için ortak.
  void drawMiniCard(
    Canvas canvas, {
    required Rect rect,
    required double titleWidthFactor,
    Color? cardColor,
    bool withImage = true,
    Color? sourceDot,
  }) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(
      r,
      Paint()..color = cardColor ?? surface,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = outline.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final inset = 10.0;
    final lineH = (rect.height - inset * 2) * 0.18;

    var dy = rect.top + inset;
    if (withImage) {
      final imgH = (rect.height - inset * 2) * 0.5;
      final imgRect = Rect.fromLTWH(
        rect.left + inset,
        dy,
        rect.width - inset * 2,
        imgH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(imgRect, const Radius.circular(8)),
        Paint()..color = muted.withValues(alpha: 0.18),
      );
      // Hayalet ikon - ortada bir resim glyph.
      final ic = imgRect.center;
      canvas.drawCircle(
        ic,
        imgRect.height * 0.18,
        Paint()..color = muted.withValues(alpha: 0.30),
      );
      dy += imgH + 8;
    }

    // Source dot + ince çubuk (kaynak adı).
    final sd = sourceDot ?? accent;
    canvas.drawCircle(
      Offset(rect.left + inset + 3, dy + 3),
      3,
      Paint()..color = sd,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + inset + 12, dy, rect.width * 0.30, 5),
        const Radius.circular(2),
      ),
      Paint()..color = muted.withValues(alpha: 0.55),
    );
    dy += 12;

    // Başlık çubukları.
    final tw = (rect.width - inset * 2) * titleWidthFactor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + inset, dy, tw, lineH * 0.65),
        const Radius.circular(3),
      ),
      Paint()..color = fg.withValues(alpha: 0.85),
    );
    dy += lineH * 0.65 + 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + inset, dy, tw * 0.7, lineH * 0.55),
        const Radius.circular(3),
      ),
      Paint()..color = fg.withValues(alpha: 0.55),
    );
  }
}

/// Sayfa 1: Layered news cards — birden fazla kaynak akışını tek bir
/// istife yığar. Üstte yine accent renkli "🔥 Gündem" rozeti.
class _LayeredFeedsPainter extends _BasePagePainter {
  _LayeredFeedsPainter({
    required super.accent,
    required super.surface,
    required super.fg,
    required super.muted,
    required super.outline,
    required super.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Üç kart istifi — arkadan öne hafif sağa eğimle.
    final cardW = w * 0.78;
    final cardH = h * 0.62;
    final centerX = w / 2;

    // Source palet — istifteki kartlar farklı kaynak hissi versin.
    final dots = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      accent,
    ];

    for (var i = 0; i < 3; i++) {
      final t = i / 2;
      final cardOpacity = 1.0 - (2 - i) * 0.15;
      final dx = centerX - cardW / 2 + (t - 0.5) * w * 0.16;
      final dy = h * 0.10 + (t * h * 0.08);
      final rect = Rect.fromLTWH(dx, dy, cardW, cardH);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((t - 0.5) * 0.07);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      // Gölge.
      final shadowRect = rect.translate(0, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(shadowRect, const Radius.circular(14)),
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? 0.30 : 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      drawMiniCard(
        canvas,
        rect: rect,
        titleWidthFactor: 0.9,
        cardColor: surface.withValues(alpha: cardOpacity),
        withImage: i == 2,
        sourceDot: dots[i],
      );
      canvas.restore();
    }

    // Ön plan: "Gündem" rozeti — istifin sağ üstüne yapışık.
    final badgeW = w * 0.30;
    final badgeH = h * 0.075;
    final badgeRect = Rect.fromLTWH(
      w * 0.58,
      h * 0.06,
      badgeW,
      badgeH,
    );
    final br = RRect.fromRectAndRadius(
      badgeRect,
      const Radius.circular(20),
    );
    canvas.drawRRect(
      br,
      Paint()..color = accent.withValues(alpha: isDark ? 0.30 : 0.18),
    );
    canvas.drawRRect(
      br,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Alev ikonu — basit üçgen dolgu.
    final fc = Offset(badgeRect.left + badgeRect.height * 0.55,
        badgeRect.center.dy);
    final flame = Path()
      ..moveTo(fc.dx, fc.dy - badgeRect.height * 0.30)
      ..quadraticBezierTo(fc.dx + 4, fc.dy, fc.dx,
          fc.dy + badgeRect.height * 0.25)
      ..quadraticBezierTo(fc.dx - 4, fc.dy, fc.dx,
          fc.dy - badgeRect.height * 0.30)
      ..close();
    canvas.drawPath(flame, Paint()..color = accent);
    // "Gündem 5x" yazısı yerine renkli iki çubuk — sade.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          badgeRect.left + badgeRect.height,
          badgeRect.center.dy - 4,
          badgeRect.width - badgeRect.height - 12,
          7,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = accent,
    );

    // Alt etiketler — "AA · BBC · DW" gibi ipucu.
    final labelY = h * 0.86;
    final dotR = 4.0;
    final spacing = w * 0.18;
    var dx = centerX - spacing;
    for (final c in dots) {
      canvas.drawCircle(
          Offset(dx, labelY), dotR, Paint()..color = c);
      dx += spacing;
    }
    // İnce ayırıcı çizgi.
    final bar = Paint()
      ..color = outline.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX - spacing * 1.3, labelY),
      Offset(centerX - spacing - 8, labelY),
      bar,
    );
    canvas.drawLine(
      Offset(centerX + spacing + 8, labelY),
      Offset(centerX + spacing * 1.3, labelY),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant _LayeredFeedsPainter old) =>
      old.accent != accent ||
      old.surface != surface ||
      old.fg != fg ||
      old.muted != muted ||
      old.outline != outline ||
      old.isDark != isDark;
}

/// Sayfa 2: Tek bir kart üstüne 3 maddelik özet ve şimşek/AI sparkle.
class _LightningSummaryPainter extends _BasePagePainter {
  _LightningSummaryPainter({
    required super.accent,
    required super.surface,
    required super.fg,
    required super.muted,
    required super.outline,
    required super.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cardRect = Rect.fromLTWH(
      w * 0.10,
      h * 0.12,
      w * 0.80,
      h * 0.78,
    );

    // Card bg.
    final card = RRect.fromRectAndRadius(cardRect, const Radius.circular(16));
    canvas.drawRRect(
      card.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.30 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(card, Paint()..color = surface);
    canvas.drawRRect(
      card,
      Paint()
        ..color = outline.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Üstte "AI ÖZET" rozeti.
    final pillRect = Rect.fromLTWH(
      cardRect.left + 14,
      cardRect.top + 14,
      w * 0.35,
      h * 0.075,
    );
    final pill = RRect.fromRectAndRadius(
      pillRect,
      Radius.circular(pillRect.height / 2),
    );
    canvas.drawRRect(
      pill,
      Paint()..color = accent.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Sparkle ikonu — küçük 4-uçlu yıldız.
    _drawSparkle(
      canvas,
      Offset(pillRect.left + pillRect.height * 0.55,
          pillRect.center.dy),
      pillRect.height * 0.30,
      accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          pillRect.left + pillRect.height,
          pillRect.center.dy - 4,
          pillRect.width - pillRect.height - 12,
          7,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = accent,
    );

    // Başlık çubukları.
    final titleY = pillRect.bottom + 14;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cardRect.left + 14, titleY, cardRect.width * 0.78, 9),
        const Radius.circular(4),
      ),
      Paint()..color = fg.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cardRect.left + 14, titleY + 14,
            cardRect.width * 0.55, 7),
        const Radius.circular(3),
      ),
      Paint()..color = fg.withValues(alpha: 0.55),
    );

    // 3 madde — accent dot + paragraf çubukları.
    var bulletY = titleY + 38;
    for (var i = 0; i < 3; i++) {
      final dotC =
          Offset(cardRect.left + 22, bulletY + 6);
      canvas.drawCircle(dotC, 4, Paint()..color = accent);
      // 2 satır paragraf.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cardRect.left + 36, bulletY,
              cardRect.width * (0.60 - i * 0.05), 5),
          const Radius.circular(2),
        ),
        Paint()..color = muted.withValues(alpha: 0.7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cardRect.left + 36, bulletY + 9,
              cardRect.width * (0.45 + i * 0.04), 5),
          const Radius.circular(2),
        ),
        Paint()..color = muted.withValues(alpha: 0.45),
      );
      bulletY += 24;
    }

    // Alt: oynat butonu (sesli brifing).
    final playR = 16.0;
    final playC = Offset(
      cardRect.right - 24 - playR,
      cardRect.bottom - 24 - playR,
    );
    canvas.drawCircle(playC, playR + 4,
        Paint()..color = accent.withValues(alpha: 0.18));
    canvas.drawCircle(playC, playR, Paint()..color = accent);
    final tri = Path()
      ..moveTo(playC.dx - 4, playC.dy - 6)
      ..lineTo(playC.dx + 6, playC.dy)
      ..lineTo(playC.dx - 4, playC.dy + 6)
      ..close();
    canvas.drawPath(tri, Paint()..color = surface);
  }

  void _drawSparkle(Canvas c, Offset center, double r, Color color) {
    final paint = Paint()..color = color;
    final p = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r * 0.32, center.dy - r * 0.32)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx + r * 0.32, center.dy + r * 0.32)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r * 0.32, center.dy + r * 0.32)
      ..lineTo(center.dx - r, center.dy)
      ..lineTo(center.dx - r * 0.32, center.dy - r * 0.32)
      ..close();
    c.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _LightningSummaryPainter old) =>
      old.accent != accent ||
      old.surface != surface ||
      old.fg != fg ||
      old.muted != muted ||
      old.outline != outline ||
      old.isDark != isDark;
}

/// Sayfa 3: Kişisel akış — segmentli filter chips, kalp/bookmark glyph,
/// "saved" haber kartı.
class _SavedAndTunedPainter extends _BasePagePainter {
  _SavedAndTunedPainter({
    required super.accent,
    required super.surface,
    required super.fg,
    required super.muted,
    required super.outline,
    required super.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Üstte filtre chips — 4 küçük pill, biri seçili (accent dolgu).
    final chipY = h * 0.10;
    final chipH = h * 0.075;
    var dx = w * 0.08;
    final chipWs = [w * 0.22, w * 0.18, w * 0.24, w * 0.20];
    for (var i = 0; i < chipWs.length; i++) {
      final selected = i == 1;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, chipY, chipWs[i], chipH),
        Radius.circular(chipH / 2),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = selected
              ? accent
              : muted.withValues(alpha: 0.18),
      );
      // İçinde ince çubuk.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            dx + 10,
            chipY + chipH * 0.42,
            chipWs[i] - 20,
            chipH * 0.16,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = selected
              ? surface.withValues(alpha: 0.85)
              : muted.withValues(alpha: 0.7),
      );
      dx += chipWs[i] + 8;
    }

    // Ana saved kart — büyük, ortada.
    final cardRect = Rect.fromLTWH(
      w * 0.10,
      h * 0.28,
      w * 0.80,
      h * 0.52,
    );
    final card = RRect.fromRectAndRadius(cardRect, const Radius.circular(16));
    canvas.drawRRect(
      card.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.30 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(card, Paint()..color = surface);
    canvas.drawRRect(
      card,
      Paint()
        ..color = outline.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Sol thumbnail.
    final thumbRect = Rect.fromLTWH(
      cardRect.left + 12,
      cardRect.top + 12,
      cardRect.width * 0.30,
      cardRect.height - 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, const Radius.circular(10)),
      Paint()..color = muted.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      thumbRect.center,
      thumbRect.shortestSide * 0.18,
      Paint()..color = muted.withValues(alpha: 0.32),
    );

    // Sağ taraf metin.
    final tx = thumbRect.right + 12;
    final tw = cardRect.right - tx - 14;
    var ty = thumbRect.top + 4;
    // Source dot + bar.
    canvas.drawCircle(
        Offset(tx + 3, ty + 3), 3, Paint()..color = accent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx + 12, ty, tw * 0.45, 5),
        const Radius.circular(2),
      ),
      Paint()..color = muted.withValues(alpha: 0.6),
    );
    ty += 14;
    // Başlık 2 satır.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty, tw, 7),
        const Radius.circular(3),
      ),
      Paint()..color = fg.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty + 12, tw * 0.85, 7),
        const Radius.circular(3),
      ),
      Paint()..color = fg.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty + 24, tw * 0.6, 6),
        const Radius.circular(3),
      ),
      Paint()..color = fg.withValues(alpha: 0.55),
    );
    ty += 40;
    // Alt mini bar (zaman / okuma süresi).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty, tw * 0.40, 5),
        const Radius.circular(2),
      ),
      Paint()..color = muted.withValues(alpha: 0.45),
    );

    // Sağ üstte bookmark ikonu — accent dolgu.
    final bmTopLeft = Offset(cardRect.right - 26, cardRect.top + 12);
    final bmW = 14.0;
    final bmH = 18.0;
    final bm = Path()
      ..moveTo(bmTopLeft.dx, bmTopLeft.dy)
      ..lineTo(bmTopLeft.dx + bmW, bmTopLeft.dy)
      ..lineTo(bmTopLeft.dx + bmW, bmTopLeft.dy + bmH)
      ..lineTo(bmTopLeft.dx + bmW / 2, bmTopLeft.dy + bmH * 0.7)
      ..lineTo(bmTopLeft.dx, bmTopLeft.dy + bmH)
      ..close();
    canvas.drawPath(bm, Paint()..color = accent);

    // Alt: kalp + ince üç çubuk (kişiselleştirme dna'sı).
    final bottomY = cardRect.bottom + 14;
    final dotR = 6.0;
    final centerX = w / 2;
    // Kalp.
    final hp = Path();
    final hx = centerX - 50;
    final hy = bottomY + dotR;
    final hsize = 12.0;
    hp.moveTo(hx, hy);
    hp.cubicTo(hx, hy - hsize, hx + hsize, hy - hsize, hx + hsize, hy);
    hp.cubicTo(hx + hsize, hy + hsize / 2, hx + hsize / 2,
        hy + hsize, hx, hy + hsize * 1.3);
    hp.cubicTo(hx - hsize / 2, hy + hsize, hx - hsize,
        hy + hsize / 2, hx - hsize, hy);
    hp.cubicTo(hx - hsize, hy - hsize, hx, hy - hsize, hx, hy);
    canvas.drawPath(hp, Paint()..color = accent);
    // İnce filtre çubukları.
    for (var i = 0; i < 4; i++) {
      final width = 28.0 - i * 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - 10 + i * 18,
              bottomY - 2 + (i.isOdd ? 3 : 0), width, 5),
          const Radius.circular(2),
        ),
        Paint()
          ..color = (i == 1 ? accent : muted)
              .withValues(alpha: i == 1 ? 0.85 : 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SavedAndTunedPainter old) =>
      old.accent != accent ||
      old.surface != surface ||
      old.fg != fg ||
      old.muted != muted ||
      old.outline != outline ||
      old.isDark != isDark;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pageIndex,
    required this.pageCount,
    required this.accent,
    required this.onNext,
    required this.onSelectAccent,
    required this.ctaLabel,
    required this.isLast,
  });

  final int pageIndex;
  final int pageCount;
  final Color accent;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectAccent;
  final String ctaLabel;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sayfa numarası + dot indicator.
          Row(
            children: [
              Text(
                '${(pageIndex + 1).toString().padLeft(2, '0')} / '
                '${pageCount.toString().padLeft(2, '0')}',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < pageCount; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: GestureDetector(
                    onTap: () => onSelectAccent(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      width: i == pageIndex ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == pageIndex
                            ? accent
                            : cs.outlineVariant.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 56,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onNext,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ctaLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isLast
                            ? Icons.tune_rounded
                            : Icons.arrow_forward_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
