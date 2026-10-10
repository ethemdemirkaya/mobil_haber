import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The native launch portrait continues into a restrained Flutter greeting.
class PusulaLaunchScene extends StatelessWidget {
  const PusulaLaunchScene({super.key, this.progress = 0});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = progress.clamp(0.0, 1.0);
    return Material(
      color: cs.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Transform.translate(
                      offset: Offset(0, -4 * math.sin(math.pi * t)),
                      child: Transform.rotate(
                        angle: .025 * math.sin(2 * math.pi * t),
                        child: Image.asset(
                          'assets/brand/wise-owl-welcome.png',
                          width: 190,
                          height: (constraints.maxHeight * .28).clamp(
                            130.0,
                            190.0,
                          ),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Pusula',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Haberlerde yönünü bul.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 17,
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
