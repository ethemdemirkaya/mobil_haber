import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bookmark_provider.dart';
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
  Widget build(BuildContext context) {
    final bookmarkCount = context.select<BookmarkProvider, int>(
      (b) => b.count,
    );

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
