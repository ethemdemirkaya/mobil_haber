import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/bookmark_provider.dart';
import '../providers/news_provider.dart';
import '../providers/preferences_provider.dart';
import 'bookmarks/bookmarks_screen.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
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
    SearchScreen(),
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
      if (news.activeSourceCount == 0) {
        news.applySources(prefs.effectiveSources);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkCount = context.select<BookmarkProvider, int>(
      (b) => b.count,
    );

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i != _index) {
            HapticFeedback.selectionClick();
          }
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Arama',
          ),
          NavigationDestination(
            icon: Badge(
              label: bookmarkCount > 0 ? Text('$bookmarkCount') : null,
              isLabelVisible: bookmarkCount > 0,
              child: const Icon(Icons.bookmark_outline),
            ),
            selectedIcon: Badge(
              label: bookmarkCount > 0 ? Text('$bookmarkCount') : null,
              isLabelVisible: bookmarkCount > 0,
              child: const Icon(Icons.bookmark),
            ),
            label: 'Kayıtlı',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
