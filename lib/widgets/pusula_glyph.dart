import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A flat, legible compass mark without decorative effects.
class PusulaGlyph extends StatelessWidget {
  const PusulaGlyph({
    super.key,
    this.size = 160,
    this.needleProgress = 1,
    this.foreground,
    this.background,
    this.accent,
    this.muted,
    this.showRim = true,
  });
  final double size, needleProgress;
  final Color? foreground, background, accent, muted;
  final bool showRim;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pusula logosu',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CompassPainter(
          foreground ?? Theme.of(context).colorScheme.primary,
          showRim,
        ),
      ),
    ),
  );
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter(this.color, this.rim);
  final Color color;
  final bool rim;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * .40;
    if (rim) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .055,
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    final needle = Path()
      ..moveTo(0, -r * .85)
      ..lineTo(r * .28, 0)
      ..lineTo(0, r * .85)
      ..lineTo(-r * .28, 0)
      ..close();
    final cutout = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * .14));
    canvas.drawPath(
      Path.combine(PathOperation.difference, needle, cutout),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.rim != rim;
}
