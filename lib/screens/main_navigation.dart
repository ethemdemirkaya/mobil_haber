import '../widgets/pusula_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/notifications/scheduled_briefing_service.dart';
import '../providers/bookmark_provider.dart';
import '../providers/news_provider.dart';
import '../providers/preferences_provider.dart';
import 'bookmarks/bookmarks_screen.dart';
import 'briefing/daily_briefing_screen.dart';
import 'cluster/cluster_screen.dart';
import 'home/home_screen.dart';
import 'personalized/personalized_feed_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    ClusterScreen(),
    PersonalizedFeedScreen(),
    BookmarksScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Splash bypass edilirse veya hot reload sonrası MainNavigation'a
    // doğrudan girilirse de kaynakların `NewsProvider`'a uygulandığından
    // emin olalım. NewsProvider zaten yüklü ise bootstrap no-op olur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final news = context.read<NewsProvider>();
      final prefs = context.read<PreferencesProvider>();
      // activeSourceCount çekim bitene kadar 0 kalır; splash'ın başlattığı
      // çekimi ikinci kez tetiklememek için "istendi mi"ye bakıyoruz.
      if (!news.hasRequestedSources) {
        news.applySources(prefs.effectiveSources);
      }
      // Zamanlanmış brifing bildirimine dokunulmuşsa onu yakalayıp
      // ilgili kategoriyle DailyBriefingScreen'i aç.
      _consumePendingBriefingTap();
    });
    ScheduledBriefingService.tappedPayload.addListener(_onBriefingTapped);
  }

  @override
  void dispose() {
    ScheduledBriefingService.tappedPayload.removeListener(_onBriefingTapped);
    super.dispose();
  }

  void _onBriefingTapped() {
    _consumePendingBriefingTap();
  }

  void _consumePendingBriefingTap() {
    final payload = ScheduledBriefingService.tappedPayload.value;
    if (payload == null || payload.isEmpty) return;
    // Tek seferlik tüket — clear et ki ekran yeniden açılınca tekrar
    // tetiklenmesin.
    ScheduledBriefingService.tappedPayload.value = null;
    // Brifing ekranını açarken payload (categoryId) ile başlat.
    // Mevcut DailyBriefingScreen kategoriyi kendi içinde yönetiyor;
    // category seçimi initial state için constructor parametresi
    // eklemek istemiyoruz — basit yol: ekranı aç, kullanıcı chip'ten seçsin.
    // Daha iyi UX için ileride initialCategoryId param eklenebilir.
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DailyBriefingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkCount = context.select<BookmarkProvider, int>((b) => b.count);

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: PusulaNavigationBar(
        selectedIndex: _index,
        bookmarkCount: bookmarkCount,
        onSelected: (i) {
          if (i != _index) HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
      ),
    );
  }
}
