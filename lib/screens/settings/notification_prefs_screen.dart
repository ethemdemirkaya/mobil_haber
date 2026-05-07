import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/category.dart';
import '../../providers/preferences_provider.dart';

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesProvider>();
    final categories = NewsCategory.values
        .where((c) => c.id != NewsCategory.all.id)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Tercihleri')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionTitle('Genel'),
          SwitchListTile(
            secondary: const Icon(Icons.flash_on_outlined),
            title: const Text('Son dakika bildirimleri'),
            subtitle: const Text(
                'Önemli gelişmelerde anında haberdar olun'),
            value: prefs.breakingNews,
            onChanged: (v) =>
                context.read<PreferencesProvider>().setBreakingNews(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Günlük özet (08:00)'),
            subtitle: const Text(
                'Sabah saatinde günün öne çıkan haberlerinden bir derleme'),
            value: prefs.dailyDigest,
            onChanged: (v) =>
                context.read<PreferencesProvider>().setDailyDigest(v),
          ),
          const SizedBox(height: 8),
          const _SectionTitle('Kategori bildirimleri'),
          for (final c in categories)
            SwitchListTile(
              secondary: Icon(c.icon, color: c.color),
              title: Text(c.name),
              value: prefs.isCategorySubscribed(c.id),
              onChanged: (v) => context
                  .read<PreferencesProvider>()
                  .toggleCategory(c.id, v),
            ),
          const SizedBox(height: 16),
          const _Note(
            'Bildirimler şu an cihazınızda yerel olarak yapılandırılır. '
            'Push entegrasyonu (FCM) sonraki sürümde aktive edilecektir.',
          ),
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

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
