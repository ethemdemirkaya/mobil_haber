import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _SectionTitle('Görünüm'),
          _ThemeModeTile(),
          _Divider(),
          _FontScaleTile(),
          SizedBox(height: 16),
          _SectionTitle('Veriler'),
          _ClearSearchTile(),
          _Divider(),
          _ClearBookmarksTile(),
          SizedBox(height: 16),
          _SectionTitle('Hakkında'),
          _AboutTile(),
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
        onSelectionChanged: (set) => context
            .read<ThemeProvider>()
            .setThemeMode(set.first),
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
        onSelectionChanged: (set) => context
            .read<ThemeProvider>()
            .setFontScale(set.first),
      ),
    );
  }
}

class _ClearSearchTile extends StatelessWidget {
  const _ClearSearchTile();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SearchProvider>().history;
    return ListTile(
      leading: const Icon(Icons.history),
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

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Uygulama'),
      subtitle: const Text('mobil_haber sürüm 1.0.0'),
      onTap: () {
        showAboutDialog(
          context: context,
          applicationName: AppConstants.appName,
          applicationVersion: '1.0.0',
          applicationIcon: const Icon(Icons.newspaper_outlined, size: 32),
          applicationLegalese:
              '© 2026 mobil_haber. Demo amaçlı bir Flutter projesidir.',
          children: const [
            SizedBox(height: 12),
            Text(
                'Material 3 tasarım dili, açık/koyu tema desteği ve mock veriyle hazırlanmış '
                'bir mobil haber uygulaması örneği.'),
          ],
        );
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
