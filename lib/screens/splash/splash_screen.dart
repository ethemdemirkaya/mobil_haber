import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/pusula_glyph.dart';
import '../main_navigation.dart';
import '../onboarding/onboarding_screen.dart';

/// A brief brand reveal runs alongside preference loading, never network loading.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();
    final preferences = context.watch<PreferencesProvider>();
    final ready = onboarding.initialized && preferences.initialized;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final cs = Theme.of(context).colorScheme;
    final destination = onboarding.completed
        ? const MainNavigation()
        : const OnboardingScreen();
    return Stack(
      children: [
        if (ready)
          destination
        else
          const Scaffold(body: Center(child: PusulaGlyph(size: 64))),
        if (!reduceMotion)
          AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              if (_intro.isCompleted) return const SizedBox.shrink();
              return IgnorePointer(
                child: Opacity(
                  opacity: (1 - _intro.value * 1.25).clamp(0.0, 1.0),
                  child: ColoredBox(
                    color: cs.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle:
                                (1 -
                                    Curves.easeOutCubic.transform(
                                      _intro.value,
                                    )) *
                                -.32,
                            child: const PusulaGlyph(size: 72),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Pusula',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
