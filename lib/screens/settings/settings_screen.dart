import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/reading_theme_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/theme_provider.dart';
import '../briefing/daily_briefing_screen.dart';
import '../live/live_news_screen.dart';
import 'about_screen.dart';
import 'ai_settings_screen.dart';
import 'data_usage_screen.dart';
import 'diagnostics_screen.dart';
import 'notification_prefs_screen.dart';
import 'reading_history_screen.dart';
import 'source_preferences_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionTitle('Görünüm'),
          _ThemeModeTile(),
          _Divider(),
          _FontScaleTile(),
          _Divider(),
          _DensityTile(),
          _Divider(),
          _ReadingModeTile(),
          SizedBox(height: 12),
          _SectionTitle('Canlı içerik'),
          _NavTile(
            icon: Icons.podcasts_outlined,
            title: 'Canlı Haberler',
            subtitle: 'AA, TRT, NTV, Sözcü, BBC, Hacker News + dış API\'ler',
            page: LiveNewsScreen(),
          ),
          _Divider(),
          _NavTile(
            icon: Icons.tune_outlined,
            title: 'Kaynak Tercihleri',
            subtitle: 'Canlı ekranda hangi kaynaklar gösterilsin',
            page: SourcePreferencesScreen(),
          ),
          _Divider(),
          _AiSettingsNavTile(),
          _Divider(),
          _NavTile(
            icon: Icons.podcasts_rounded,
            title: 'Sesli Brifing',
            subtitle: 'Bugünün haberlerini AI özetiyle dinle',
            page: DailyBriefingScreen(),
          ),
          SizedBox(height: 12),
          _SectionTitle('Tercihler'),
          _NavTile(
            icon: Icons.notifications_outlined,
            title: 'Bildirim Tercihleri',
            subtitle: 'Son dakika, günlük özet ve kategori bildirimleri',
            page: NotificationPrefsScreen(),
          ),
          _Divider(),
          _NavTile(
            icon: Icons.data_saver_off_outlined,
            title: 'Veri Kullanımı',
            subtitle: 'Düşük çözünürlük, otomatik oynatma',
            page: DataUsageScreen(),
          ),
          SizedBox(height: 12),
          _SectionTitle('Veriler'),
          _ReadingHistoryNavTile(),
          _Divider(),
          _ClearSearchTile(),
          _Divider(),
          _ClearBookmarksTile(),
          SizedBox(height: 12),
          _SectionTitle('Geliştirici'),
          _NavTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Tanılama',
            subtitle: 'Servis durumu, kaynak sağlığı, sürüm bilgisi',
            page: DiagnosticsScreen(),
          ),
          SizedBox(height: 12),
          _SectionTitle('Hakkında'),
          _NavTile(
            icon: Icons.info_outline,
            title: 'Uygulama hakkında',
            subtitle:
                '${AppConstants.appName} sürüm ${AppConstants.appVersion}',
            page: AboutScreen(),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: cs.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile();

  static const _labels = {
    ThemeMode.system: 'Sistem',
    ThemeMode.light: 'Açık',
    ThemeMode.dark: 'Koyu',
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('Tema'),
      subtitle: Text(_labels[theme.themeMode]!),
      trailing: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto, size: 16),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.wb_sunny_outlined, size: 16),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined, size: 16),
          ),
        ],
        selected: {theme.themeMode},
        onSelectionChanged: (set) =>
            context.read<ThemeProvider>().setThemeMode(set.first),
      ),
    );
  }
}

class _FontScaleTile extends StatelessWidget {
  const _FontScaleTile();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ListTile(
      leading: const Icon(Icons.format_size_outlined),
      title: const Text('Yazı boyutu'),
      subtitle: Text(theme.fontScale.label),
      trailing: SegmentedButton<AppFontScale>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: AppFontScale.small,
            label: Text('S', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment(
            value: AppFontScale.medium,
            label: Text('M'),
          ),
          ButtonSegment(
            value: AppFontScale.large,
            label: Text('L', style: TextStyle(fontSize: 16)),
          ),
        ],
        selected: {theme.fontScale},
        onSelectionChanged: (set) =>
            context.read<ThemeProvider>().setFontScale(set.first),
      ),
    );
  }
}

class _DensityTile extends StatelessWidget {
  const _DensityTile();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ReadingThemeProvider>();
    return ListTile(
      leading: const Icon(Icons.view_agenda_outlined),
      title: const Text('Liste yoğunluğu'),
      subtitle: Text(t.density.label),
      trailing: SegmentedButton<ListDensity>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ListDensity.comfortable,
            icon: Icon(Icons.density_medium, size: 16),
          ),
          ButtonSegment(
            value: ListDensity.compact,
            icon: Icon(Icons.density_small, size: 16),
          ),
        ],
        selected: {t.density},
        onSelectionChanged: (set) =>
            context.read<ReadingThemeProvider>().setDensity(set.first),
      ),
    );
  }
}

class _ReadingModeTile extends StatelessWidget {
  const _ReadingModeTile();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ReadingThemeProvider>();
    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: const Text('Okuma modu'),
      subtitle: Text(
        t.readingMode == ReadingMode.sepia
            ? 'Sepya — kremrengi okuma teması'
            : 'Standart',
      ),
      trailing: SegmentedButton<ReadingMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ReadingMode.normal,
            icon: Icon(Icons.brightness_5, size: 16),
          ),
          ButtonSegment(
            value: ReadingMode.sepia,
            icon: Icon(Icons.menu_book_outlined, size: 16),
          ),
        ],
        selected: {t.readingMode},
        onSelectionChanged: (set) =>
            context.read<ReadingThemeProvider>().setReadingMode(set.first),
      ),
    );
  }
}

class _AiSettingsNavTile extends StatelessWidget {
  const _AiSettingsNavTile();

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final subtitle = !ai.enabled
        ? 'Kapalı — etkinleştirmek için dokun'
        : ai.hasApiKey
            ? '${ai.currentModelLabel} • OpenRouter'
            : 'Etkin ama API anahtarı gerekiyor';
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.auto_awesome, color: cs.primary, size: 20),
      ),
      title: const Text('Yapay Zeka Özetleme'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
        );
      },
    );
  }
}

class _ReadingHistoryNavTile extends StatelessWidget {
  const _ReadingHistoryNavTile();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<ReadingHistoryProvider>().count;
    return ListTile(
      leading: const Icon(Icons.history),
      title: const Text('Okuma Geçmişi'),
      subtitle: Text('$count makale'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ReadingHistoryScreen(),
          ),
        );
      },
    );
  }
}

class _ClearSearchTile extends StatelessWidget {
  const _ClearSearchTile();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SearchProvider>().history;
    return ListTile(
      leading: const Icon(Icons.search_off_outlined),
      title: const Text('Arama geçmişini temizle'),
      subtitle: Text('${history.length} kayıt'),
      enabled: history.isNotEmpty,
      onTap: () async {
        final confirmed = await _confirm(
          context,
          'Arama geçmişini temizle',
          'Tüm kayıtlı arama sorguları silinecek.',
        );
        if (confirmed && context.mounted) {
          context.read<SearchProvider>().clearHistory();
          _snack(context, 'Arama geçmişi temizlendi');
        }
      },
    );
  }
}

class _ClearBookmarksTile extends StatelessWidget {
  const _ClearBookmarksTile();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<BookmarkProvider>().count;
    return ListTile(
      leading: const Icon(Icons.bookmarks_outlined),
      title: const Text('Kaydedilenleri temizle'),
      subtitle: Text('$count kayıtlı haber'),
      enabled: count > 0,
      onTap: () async {
        final confirmed = await _confirm(
          context,
          'Kaydedilenleri temizle',
          'Kaydettiğiniz tüm haberler kaldırılacak.',
        );
        if (confirmed && context.mounted) {
          context.read<BookmarkProvider>().clearAll();
          _snack(context, 'Kayıtlı haberler temizlendi');
        }
      },
    );
  }
}

Future<bool> _confirm(
    BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Onayla'),
        ),
      ],
    ),
  );
  return result == true;
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
}
