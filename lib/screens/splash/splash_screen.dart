import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../main_navigation.dart';
import '../onboarding/onboarding_screen.dart';

/// Pusula splash — pusula iğnesi animasyonlu marka karşılaması.
///
/// Tasarım özeti:
///   - Tam ekran branded gradient (primary → tertiary).
///   - Merkezde dairesel pusula gövdesi (rim + tick mark + dönen iğne).
///   - Marka adı ve tagline yumuşak fade + scale animasyonu.
///   - Alt köşede "Yapay zekayla özetli haber" rozeti — değer önerisi.
///   - 4 yıldız parıltısı sürekli idle animasyon — premium hissi.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _needle;
  late final AnimationController _sparkle;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _logoFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOut),
    );
    _fade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _entry.forward();

    // Pusula iğnesi rotation — yavaş geriden gelip kuzeyi bulan iğne.
    _needle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    // Yıldız parıltıları sürekli idle.
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scheduleNavigate();
  }

  Future<void> _scheduleNavigate() async {
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    final onboarding = context.read<OnboardingProvider>();
    final prefs = context.read<PreferencesProvider>();
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
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _needle.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Brand renk paleti — koyu mor/mavi tonlarda derin gradient.
    const top = Color(0xFF1B0E45);
    const mid = Color(0xFF3A1A8C);
    const bottom = Color(0xFF6938E0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, mid, bottom],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arka radyal halkalar — iğnenin etrafında atmosfer hissi.
            Positioned.fill(
              child: CustomPaint(
                painter: _RadialRingsPainter(),
              ),
            ),

            // Sürekli yıldız parıltıları (4 farklı pozisyonda).
            ..._buildSparkles(),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Pusula gövdesi
                  AnimatedBuilder(
                    animation: Listenable.merge([_entry, _needle]),
                    builder: (context, _) {
                      final scaleVal = _scale.value;
                      final logoOp = _logoFade.value;
                      return Transform.scale(
                        scale: scaleVal,
                        child: Opacity(
                          opacity: logoOp,
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: CustomPaint(
                              painter: _CompassPainter(
                                needleProgress: Curves.easeOutCubic
                                    .transform(_needle.value),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // Marka adı + tagline
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) {
                            return const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFFFFF),
                                Color(0xFFE0CCFF),
                              ],
                            ).createShader(rect);
                          },
                          child: Text(
                            AppConstants.appName,
                            style: textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              fontSize: 44,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            AppConstants.appTagline,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Alt değer önerisi rozetleri
                  FadeTransition(
                    opacity: _fade,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ValueChip(
                            icon: Icons.auto_awesome,
                            label: 'Yapay zeka özetli',
                          ),
                          _ValueChip(
                            icon: Icons.podcasts_rounded,
                            label: 'Sesli brifing',
                          ),
                          _ValueChip(
                            icon: Icons.layers_outlined,
                            label: '27+ kaynak',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // İnce loading bar — splash'ın yaşadığını gösterir.
                  FadeTransition(
                    opacity: _fade,
                    child: SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation(
                              Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    // Belirli pozisyonlarda yumuşak parıltı animasyonları.
    const positions = <_SparkleSpec>[
      _SparkleSpec(left: 50, top: 110, size: 14, phase: 0.0),
      _SparkleSpec(right: 40, top: 180, size: 10, phase: 0.3),
      _SparkleSpec(left: 70, bottom: 240, size: 12, phase: 0.6),
      _SparkleSpec(right: 80, bottom: 320, size: 8, phase: 0.85),
    ];
    return [
      for (final p in positions)
        Positioned(
          left: p.left,
          right: p.right,
          top: p.top,
          bottom: p.bottom,
          child: AnimatedBuilder(
            animation: _sparkle,
            builder: (context, _) {
              final t = (_sparkle.value + p.phase) % 1.0;
              final opacity = (math.sin(t * math.pi) * 0.7).clamp(0.0, 0.7);
              return Opacity(
                opacity: opacity,
                child: Icon(
                  Icons.auto_awesome,
                  size: p.size,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
    ];
  }
}

class _SparkleSpec {
  const _SparkleSpec({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.phase,
  });
  final double? left, right, top, bottom;
  final double size;
  final double phase;
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pusula gövdesi: dış halka, kompas rüzgargülü işaretleri, kırmızı/beyaz
/// dönen iğne, merkez disk. Tek `Canvas`'ta tek geçişte çiziliyor.
class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.needleProgress});
  final double needleProgress; // 0.0 → 1.0; iğnenin başlangıçtan kuzeye dönüşü

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // 1) Dış glow — soft drop shadow.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.05))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(c, r * 0.96, glow);

    // 2) Dış halka — beyaz ince çember.
    final ringOuter = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r * 0.92, ringOuter);

    // 3) Cam yüzey radyal gradient (alttan yukarı parlaklık)
    final glass = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.4,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.85));
    canvas.drawCircle(c, r * 0.86, glass);

    // 4) Tick marks — 12 büyük (her 30°), 24 küçük her 15°.
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final angle = i * (math.pi / 12); // 15° aralık
      final isMajor = i % 2 == 0;
      tickPaint.strokeWidth = isMajor ? 2.4 : 1.2;
      tickPaint.color = Colors.white
          .withValues(alpha: isMajor ? 0.7 : 0.35);
      final outerR = r * 0.86;
      final innerR = isMajor ? r * 0.78 : r * 0.82;
      final p1 = Offset(
        c.dx + outerR * math.cos(angle),
        c.dy + outerR * math.sin(angle),
      );
      final p2 = Offset(
        c.dx + innerR * math.cos(angle),
        c.dy + innerR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 5) N/E/S/W harf işaretleri — sadece N (Kuzey) prominently.
    final tp = TextPainter(
      text: const TextSpan(
        text: 'K',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r * 0.7));

    // 6) İğne — kırmızı (kuzey) + beyaz (güney) kanatlar.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // Başta -PI/4 sapması, ilerledikçe 0'a (dik) yaklaşır.
    final rotationStart = -math.pi / 3;
    final rotation = rotationStart * (1 - needleProgress);
    canvas.rotate(rotation);

    final needleLen = r * 0.62;
    final needleWidth = r * 0.10;

    // Kuzey kanat — kırmızı.
    final northPath = Path()
      ..moveTo(0, -needleLen)
      ..lineTo(needleWidth, 0)
      ..lineTo(-needleWidth, 0)
      ..close();
    final northPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF5757), Color(0xFFB02020)],
      ).createShader(Rect.fromLTWH(
        -needleWidth, -needleLen, needleWidth * 2, needleLen,
      ));
    canvas.drawPath(northPath, northPaint);

    // Güney kanat — beyaz/grimsi.
    final southPath = Path()
      ..moveTo(0, needleLen)
      ..lineTo(needleWidth, 0)
      ..lineTo(-needleWidth, 0)
      ..close();
    final southPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD0CDDC), Color(0xFF8E89A8)],
      ).createShader(Rect.fromLTWH(
        -needleWidth, 0, needleWidth * 2, needleLen,
      ));
    canvas.drawPath(southPath, southPaint);

    canvas.restore();

    // 7) Merkez disk — krem dikeli, parlak halo.
    final centerHalo = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(c, r * 0.07, centerHalo);

    final centerDisk = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.06));
    canvas.drawCircle(c, r * 0.06, centerDisk);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.needleProgress != needleProgress;
}

/// Arka planda yavaş, soft radyal halkalar — atmosfer.
class _RadialRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final maxR = math.max(size.width, size.height) * 0.7;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 1; i <= 5; i++) {
      paint.color = Colors.white.withValues(alpha: 0.045 - i * 0.005);
      canvas.drawCircle(c, maxR * (i / 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialRingsPainter old) => false;
}
