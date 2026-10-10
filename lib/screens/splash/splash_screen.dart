import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/pusula_launch_scene.dart';
import '../main_navigation.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Native splash covers Flutter until its first frame has been rasterized.
      // Widget-test bindings have no engine rasterizer to wait for.
      if (WidgetsBinding.instance is WidgetsFlutterBinding) {
        await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
      }
      if (mounted) _intro.forward();
    });
  }

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
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final showIntro = !ready || (!reduceMotion && !_intro.isCompleted);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              ExcludeSemantics(
                excluding: showIntro,
                child: onboarding.completed
                    ? const MainNavigation()
                    : const OnboardingScreen(),
              ),
            if (showIntro)
              AbsorbPointer(
                child: Semantics(
                  label: 'Pusula açılıyor',
                  child: Opacity(
                    opacity: ready && !reduceMotion
                        ? 1 -
                              const Interval(
                                .78,
                                1,
                                curve: Curves.easeOut,
                              ).transform(_intro.value)
                        : 1,
                    child: PusulaLaunchScene(
                      progress: reduceMotion ? 0 : _intro.value,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
