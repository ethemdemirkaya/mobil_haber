import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/bookmark_provider.dart';
import 'providers/news_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/reading_history_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';

class MobilHaberApp extends StatelessWidget {
  const MobilHaberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => ReadingHistoryProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final overlay = theme.themeMode == ThemeMode.dark
              ? SystemUiOverlayStyle.light
              : theme.themeMode == ThemeMode.light
                  ? SystemUiOverlayStyle.dark
                  : (MediaQuery.platformBrightnessOf(context) ==
                          Brightness.dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark);
          SystemChrome.setSystemUIOverlayStyle(
            overlay.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
          );

          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode,
            theme: AppTheme.light(scale: theme.fontScale),
            darkTheme: AppTheme.dark(scale: theme.fontScale),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
