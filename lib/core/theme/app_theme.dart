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
    final colorScheme = _colors(Brightness.light);
    return _buildTheme(colorScheme, scale);
  }

  static ThemeData dark({AppFontScale scale = AppFontScale.medium}) {
    final colorScheme = _colors(Brightness.dark);
    return _buildTheme(colorScheme, scale);
  }

  static ColorScheme _colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: dark ? const Color(0xFFF09097) : AppColors.brandSeed,
      onPrimary: dark ? const Color(0xFF3C0A12) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF46252A)
          : const Color(0xFFF3E1E0),
      onPrimaryContainer: dark
          ? const Color(0xFFFFDADB)
          : const Color(0xFF721A27),
      secondary: dark ? const Color(0xFFC8BEB1) : const Color(0xFF655B50),
      onSecondary: dark ? const Color(0xFF26221D) : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF36312B)
          : const Color(0xFFECE6DC),
      onSecondaryContainer: dark
          ? const Color(0xFFECE6DC)
          : const Color(0xFF302A24),
      tertiary: dark ? const Color(0xFFC8BEB1) : const Color(0xFF655B50),
      onTertiary: dark ? const Color(0xFF26221D) : Colors.white,
      tertiaryContainer: dark
          ? const Color(0xFF36312B)
          : const Color(0xFFECE6DC),
      onTertiaryContainer: dark
          ? const Color(0xFFECE6DC)
          : const Color(0xFF302A24),
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: dark ? const Color(0xFF690005) : Colors.white,
      surface: dark ? const Color(0xFF191816) : const Color(0xFFF6F3EE),
      onSurface: dark ? const Color(0xFFEDE8DF) : const Color(0xFF242321),
      onSurfaceVariant: dark
          ? const Color(0xFFBDB6AC)
          : const Color(0xFF6D675F),
      outline: dark ? const Color(0xFF82796F) : const Color(0xFF8C8378),
      outlineVariant: dark ? const Color(0xFF3E3933) : const Color(0xFFDED8CE),
      surfaceContainerLowest: dark
          ? const Color(0xFF141311)
          : const Color(0xFFFFFDFA),
      surfaceContainerLow: dark
          ? const Color(0xFF211F1C)
          : const Color(0xFFFBF9F5),
      surfaceContainer: dark
          ? const Color(0xFF26231F)
          : const Color(0xFFF0ECE5),
      surfaceContainerHigh: dark
          ? const Color(0xFF2D2925)
          : const Color(0xFFEBE5DC),
      surfaceContainerHighest: dark
          ? const Color(0xFF342F29)
          : const Color(0xFFE8E2D8),
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, AppFontScale scale) {
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colorScheme.surface,
    );
    final f = scale.factor;

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 26 * f,
          fontFamily: 'Newsreader',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        // Label rengi seçili duruma göre değişiyor; aksi halde dark mode'da
        // selected chip arkaplanı ile yazı tonu çok yakınlaşıp okunaksız
        // kalıyordu.
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13 * f,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurfaceVariant;
          }),
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13 * f,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(
          size: 16,
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurfaceVariant;
          }),
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 26, color: colorScheme.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5 * f,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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

  static TextTheme _scaledTextTheme(TextTheme base, double f, ColorScheme cs) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: 'Newsreader',
        fontSize: 57 * f,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: 'Newsreader',
        fontSize: 45 * f,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: 'Newsreader',
        fontSize: 36 * f,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: 'Newsreader',
        height: 1.15,
        fontSize: 32 * f,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'Newsreader',
        height: 1.15,
        fontSize: 26 * f,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: 'Newsreader',
        height: 1.15,
        fontSize: 24 * f,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Newsreader',
        height: 1.15,
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
