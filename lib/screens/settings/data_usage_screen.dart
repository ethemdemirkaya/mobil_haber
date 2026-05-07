import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/preferences_provider.dart';

class DataUsageScreen extends StatelessWidget {
  const DataUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prefs = context.watch<PreferencesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Veri Kullanımı')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.data_saver_on_outlined,
                    color: cs.onPrimaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Veri tasarrufu özellikleriyle mobil verinizi koruyun.',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: const Text('Düşük çözünürlüklü görseller'),
            subtitle: const Text(
                'Hücresel veriyle açıkken küçük boyutlu görsel indirilir'),
            value: prefs.dataSaverImages,
            onChanged: (v) =>
                context.read<PreferencesProvider>().setDataSaverImages(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline),
            title: const Text('Otomatik içerik oynatma'),
            subtitle: const Text(
                'Liste görünümünde animasyonlu içerikler otomatik oynar'),
            value: prefs.dataSaverAutoplay,
            onChanged: (v) =>
                context.read<PreferencesProvider>().setDataSaverAutoplay(v),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Önbelleği temizle'),
            subtitle: const Text(
                'Görsel önbelleği ve geçici dosyalar silinir'),
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content: Text('Önbellek temizlendi'),
                  behavior: SnackBarBehavior.floating,
                ));
            },
          ),
        ],
      ),
    );
  }
}
