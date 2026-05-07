import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

enum AppFontScale { small, medium, large }

extension AppFontScaleX on AppFontScale {
  double get factor {
    switch (this) {
      case AppFontScale.small:
        return 0.92;
      case AppFontScale.medium:
        return 1.0;
      case AppFontScale.large:
        return 1.12;
    }
  }

  String get label {
    switch (this) {
      case AppFontScale.small:
        return 'Küçük';
      case AppFontScale.medium:
        return 'Normal';
      case AppFontScale.large:
        return 'Büyük';
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light({AppFontScale scale = AppFontScale.medium}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandSeed,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme, scale);
  }

  static ThemeData dark({AppFontScale scale = AppFontScale.medium}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandSeed,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme, scale);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, AppFontScale scale) {
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
    );
    final f = scale.factor;

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 22 * f,
          color: colorScheme.onSurface,
        ),
        systemOverlayStyle: colorScheme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary,
        labelStyle: TextStyle(
          fontSize: 13 * f,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 13 * f,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12 * f,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 15 * f,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.6,
        space: 0,
      ),
      textTheme: _scaledTextTheme(base.textTheme, f, colorScheme),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _scaledTextTheme(
    TextTheme base,
    double f,
    ColorScheme cs,
  ) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 57 * f),
      displayMedium: base.displayMedium?.copyWith(fontSize: 45 * f),
      displaySmall: base.displaySmall?.copyWith(fontSize: 36 * f),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32 * f,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26 * f,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22 * f,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20 * f,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16 * f,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14 * f,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16 * f, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14 * f, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12 * f,
        color: cs.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14 * f,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12 * f),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11 * f),
    );
  }
}
