import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/pusula_glyph.dart';
import '../main_navigation.dart';
import '../onboarding/onboarding_screen.dart';

/// Pusula splash — uygulamanın geri kalanı ile tutarlı, tema-uyumlu marka
/// karşılaması. Hardcoded mor gradient yerine theme'in `colorScheme`
/// renklerini kullanır; light/dark mode'a otomatik uyum sağlar.
///
/// Kompozisyon:
///   - Tam ekran tema yüzeyi (light: krem, dark: koyu graphite).
///   - Üstte hafif brand-renkli halo — aydınlatma hissi.
///   - Merkezde [PusulaGlyph]: dış halka + dönüp kuzeyi bulan iğne.
///   - Logo altı "Pusula" wordmark + tagline (theme typography).
///   - Alt: ince animasyonlu progress + sürüm yazısı.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _needle;
  late final Animation<double> _glyphFade;
  late final Animation<double> _glyphScale;
  late final Animation<double> _wordmarkFade;
  late final Animation<double> _wordmarkSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    // Edge-to-edge sistem barlarına geçiş — splash boydan boya nefes alsın.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Glyph: 0–55% ile fade-in + soft scale.
    _glyphFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOut),
    );
    _glyphScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    // Wordmark: 35–80% — glyph oturduktan sonra yazı yukarı kayarak gelir.
    _wordmarkFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.35, 0.80, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
      ),
    );
    // Footer: 60–100% — son nefes.
    _footerFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );
    _entry.forward();

    // İğne ayrı kontrol — daha uzun ve "yön bulma" hissi.
    _needle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();

    _scheduleNavigate();
  }

  Future<void> _scheduleNavigate() async {
    // Glyph + needle animasyonu için minimum sahne süresi.
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;

    final onboarding = context.read<OnboardingProvider>();
    final prefs = context.read<PreferencesProvider>();

    // Provider init bekleme — 4 sn cap. Her ikisi de event-driven değil
    // değildi; kısa polling burada makul (splash zaten görünüyor).
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while ((!onboarding.initialized || !prefs.initialized) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    if (onboarding.completed && mounted) {
      // ignore: use_build_context_synchronously
      context.read<NewsProvider>().applySources(prefs.effectiveSources);
    }

    final next = onboarding.completed
        ? const MainNavigation()
        : const OnboardingScreen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) {
          // Splash → next ekran: hafif scale + fade. Hard cut yok.
          final scale = Tween<double>(begin: 1.04, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _needle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Splash yüzeyine göre status bar ikonlarını ayarla.
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Üstten hafif primary-brand halo — aydınlatma hissi, hardcoded
            // koyu mor yerine app brand rengini referans alır.
            Positioned.fill(
              child: CustomPaint(
                painter: _SoftBrandHaloPainter(
                  color: cs.primary,
                  isDark: isDark,
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),

                  // Pusula glyph — glow ring + animasyonlu iğne dönüşü.
                  AnimatedBuilder(
                    animation: Listenable.merge([_entry, _needle]),
                    builder: (context, _) {
                      return Opacity(
                        opacity: _glyphFade.value,
                        child: Transform.scale(
                          scale: _glyphScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow halo arkada
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withValues(
                                        alpha: isDark ? 0.38 : 0.22,
                                      ),
                                      blurRadius: 64,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              PusulaGlyph(
                                size: 168,
                                needleProgress: Curves.easeOutCubic
                                    .transform(_needle.value),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // Wordmark + tagline.
                  AnimatedBuilder(
                    animation: _entry,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _wordmarkFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _wordmarkSlide.value),
                          child: Column(
                            children: [
                              Text(
                                AppConstants.appName,
                                style: tt.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  color: cs.onSurface,
                                  fontSize: 44,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _TaglinePill(
                                text: AppConstants.appTagline,
                                primary: cs.primary,
                                onPrimary: cs.onPrimary,
                                surface: cs.surface,
                                fg: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 6),

                  // Footer — pulsing dots + version.
                  FadeTransition(
                    opacity: _footerFade,
                    child: Column(
                      children: [
                        _PulsingDots(color: cs.primary),
                        const SizedBox(height: 14),
                        Text(
                          'v${AppConstants.appVersion}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tagline'ı brand renginde ince çerçeveli, kompakt bir pill içine alır.
class _TaglinePill extends StatelessWidget {
  const _TaglinePill({
    required this.text,
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.fg,
  });

  final String text;
  final Color primary;
  final Color onPrimary;
  final Color surface;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.18),
            primary.withValues(alpha: 0.07),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: primary.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Üst yarıda yumuşak brand-renkli radyal aydınlatma — splash'a derinlik
/// katar. Light mode'da çok hafif, dark mode'da biraz daha belirgin.
class _SoftBrandHaloPainter extends CustomPainter {
  _SoftBrandHaloPainter({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.32);
    final maxR = math.max(size.width, size.height) * 0.7;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.18 : 0.10),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: maxR));
    canvas.drawCircle(c, maxR, paint);

    // İnce ikinci halo — alt köşede, simetri için.
    final c2 = Offset(size.width * 0.5, size.height * 1.05);
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.10 : 0.06),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c2, radius: maxR * 0.8));
    canvas.drawCircle(c2, maxR * 0.8, paint2);
  }

  @override
  bool shouldRepaint(covariant _SoftBrandHaloPainter old) =>
      old.color != color || old.isDark != isDark;
}

/// Yükleme göstergesi — 3 nokta sırayla dalgalanır.
class _PulsingDots extends StatefulWidget {
  const _PulsingDots({required this.color});
  final Color color;

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i / 3) % 1.0;
            final v = (math.sin(phase * 2 * math.pi) + 1) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: 0.45 + 0.55 * v,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.35 + 0.65 * v),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
