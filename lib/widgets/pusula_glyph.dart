import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pusula markasının görsel kimliği — minimal, çift kanatlı pusula iğnesi
/// dış halka ve N işaretiyle birlikte. Splash, onboarding ve "hakkında"
/// gibi marka anlarında tek bir tutarlı motif olarak kullanılır.
///
/// `needleProgress`:
///   - 0.0 → iğne sapmış (kuzey-batı'ya doğru ~60°).
///   - 1.0 → iğne kuzeyi göstermekte (dik).
/// Tamamlanmış statik görünüm için 1.0 verin.
class PusulaGlyph extends StatelessWidget {
  const PusulaGlyph({
    super.key,
    this.size = 160,
    this.needleProgress = 1.0,
    this.foreground,
    this.background,
    this.accent,
    this.muted,
    this.showRim = true,
  });

  final double size;
  final double needleProgress;

  /// İğnenin kuzey kanat rengi. Verilmezse `colorScheme.primary` kullanılır.
  final Color? foreground;

  /// Cam yüzey/disk arkaplan rengi. Verilmezse `colorScheme.surface`.
  final Color? background;

  /// İkincil vurgu (rim, tick mark). Verilmezse `colorScheme.outline`.
  final Color? accent;

  /// Güney kanat ve sönük detaylar. Verilmezse `colorScheme.onSurfaceVariant`.
  final Color? muted;

  /// Dış halkayı gizle (örn. küçük rozet kullanımları için).
  final bool showRim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PusulaGlyphPainter(
          needleProgress: needleProgress.clamp(0.0, 1.0),
          fg: foreground ?? cs.primary,
          bg: background ?? cs.surface,
          accent: accent ?? cs.outline,
          muted: muted ?? cs.onSurfaceVariant,
          showRim: showRim,
        ),
      ),
    );
  }
}

class _PusulaGlyphPainter extends CustomPainter {
  _PusulaGlyphPainter({
    required this.needleProgress,
    required this.fg,
    required this.bg,
    required this.accent,
    required this.muted,
    required this.showRim,
  });

  final double needleProgress;
  final Color fg;
  final Color bg;
  final Color accent;
  final Color muted;
  final bool showRim;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    if (showRim) {
      // Soft halo — hafif glow.
      final halo = Paint()
        ..color = fg.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(c, r * 0.92, halo);

      // Cam disk.
      final disc = Paint()..color = bg;
      canvas.drawCircle(c, r * 0.88, disc);

      // İnce dış halka.
      final ring = Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(c, r * 0.88, ring);

      // Tick mark'lar (kompas yönleri).
      final tick = Paint()
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.5);
      for (var i = 0; i < 24; i++) {
        final angle = i * (math.pi / 12);
        final isCardinal = i % 6 == 0; // N/E/S/W
        final isMajor = i % 2 == 0;
        tick.strokeWidth = isCardinal ? 2.4 : (isMajor ? 1.4 : 0.8);
        tick.color = accent.withValues(
          alpha: isCardinal ? 0.85 : (isMajor ? 0.55 : 0.28),
        );
        final outerR = r * 0.86;
        final innerR =
            isCardinal ? r * 0.74 : (isMajor ? r * 0.79 : r * 0.82);
        final p1 = Offset(
          c.dx + outerR * math.cos(angle),
          c.dy + outerR * math.sin(angle),
        );
        final p2 = Offset(
          c.dx + innerR * math.cos(angle),
          c.dy + innerR * math.sin(angle),
        );
        canvas.drawLine(p1, p2, tick);
      }

      // K (Kuzey) harfi — markamız Türkçe olduğu için.
      final tp = TextPainter(
        text: TextSpan(
          text: 'K',
          style: TextStyle(
            color: fg,
            fontSize: r * 0.16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r * 0.66));
    }

    // İğne — sapmadan kuzeye doğru animasyonlu.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    final rotationStart = -math.pi / 3; // başlangıç sapması (~-60°)
    final rotation = rotationStart * (1 - needleProgress);
    canvas.rotate(rotation);

    final needleLen = r * (showRim ? 0.62 : 0.78);
    final needleWidth = r * (showRim ? 0.085 : 0.11);

    // Kuzey kanat — primary brand renginde.
    final northPath = Path()
      ..moveTo(0, -needleLen)
      ..lineTo(needleWidth, 0)
      ..lineTo(-needleWidth, 0)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fg, fg.withValues(alpha: 0.78)],
        ).createShader(Rect.fromLTWH(
          -needleWidth, -needleLen, needleWidth * 2, needleLen,
        )),
    );

    // Güney kanat — sönük, theme bazlı.
    final southPath = Path()
      ..moveTo(0, needleLen)
      ..lineTo(needleWidth, 0)
      ..lineTo(-needleWidth, 0)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            muted.withValues(alpha: 0.55),
            muted.withValues(alpha: 0.30),
          ],
        ).createShader(Rect.fromLTWH(
          -needleWidth, 0, needleWidth * 2, needleLen,
        )),
    );

    canvas.restore();

    // Merkez disk — krem highlight + brand renk.
    if (showRim) {
      final centerHalo = Paint()
        ..color = fg.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(c, r * 0.075, centerHalo);
    }
    final centerDisk = Paint()..color = bg;
    canvas.drawCircle(c, r * 0.055, centerDisk);
    final centerDot = Paint()..color = fg;
    canvas.drawCircle(c, r * 0.028, centerDot);
  }

  @override
  bool shouldRepaint(covariant _PusulaGlyphPainter old) =>
      old.needleProgress != needleProgress ||
      old.fg != fg ||
      old.bg != bg ||
      old.accent != accent ||
      old.muted != muted ||
      old.showRim != showRim;
}
