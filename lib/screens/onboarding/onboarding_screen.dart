import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/news_source.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../main_navigation.dart';
import 'source_picker_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorA,
    required this.colorB,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color colorA;
  final Color colorB;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      // v2 (özetleyici) mesajı: "Birleştir + özetle" değer önerisi.
      title: 'Çok kaynaktan\ntek bir özet akışı',
      subtitle:
          '27+ haber kaynağından gelen başlıkları birleştirip kısa özetlerle sunuyoruz.',
      icon: Icons.layers_outlined,
      colorA: Color(0xFFE5484D),
      colorB: Color(0xFFF87171),
    ),
    _OnboardingPage(
      title: 'Hızlı oku,\nzamanını kazan',
      subtitle:
          'Tam metin yerine net özetler. Detay istersen tek dokunuşla orijinal kaynağa atla.',
      icon: Icons.bolt_outlined,
      colorA: Color(0xFF1E88E5),
      colorB: Color(0xFF60A5FA),
    ),
    _OnboardingPage(
      title: 'Sevdiklerini kaydet,\nsonra okumayı unutma',
      subtitle:
          'Kaydetme listesi, okuma geçmişi ve kategori filtrelerle hiçbir haberi kaçırma.',
      icon: Icons.bookmark_added_outlined,
      colorA: Color(0xFF7C3AED),
      colorB: Color(0xFFA78BFA),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// İntro slider'ından "Atla" denirse: önerilen kaynaklarla doğrudan
  /// MainNavigation'a geçeriz. Kullanıcı yine ayarlardan değiştirebilir.
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

  /// Son intro sayfasından devam: kaynak seçim ekranına yönlendirir.
  /// SourcePickerScreen kendi `_finish()` içinde onboarding'i tamamlayıp
  /// MainNavigation'a geçer.
  void _continueToPicker() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const SourcePickerScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0, 0.05),
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
    final page = _pages[_index];
    final last = _index == _pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [page.colorA, page.colorB],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!last)
                      TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Atla'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(p.icon,
                                size: 86, color: Colors.white),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.18,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            p.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.92),
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final selected = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          width: selected ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: page.colorA,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        child: Text(last ? 'Kaynakları seç' : 'Devam'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
