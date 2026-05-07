import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/external_news_repository.dart';
import '../../providers/external_news_provider.dart';
import '../../providers/preferences_provider.dart';

class SourcePreferencesScreen extends StatefulWidget {
  const SourcePreferencesScreen({super.key});

  @override
  State<SourcePreferencesScreen> createState() =>
      _SourcePreferencesScreenState();
}

class _SourcePreferencesScreenState extends State<SourcePreferencesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ExternalNewsProvider>();
      if (p.sources.isEmpty) p.loadSources();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final external = context.watch<ExternalNewsProvider>();
    final prefs = context.watch<PreferencesProvider>();

    final sources = external.sources;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaynak Tercihleri'),
        actions: [
          if (prefs.disabledSourceCount > 0)
            TextButton(
              onPressed: () =>
                  context.read<PreferencesProvider>().resetSourcePreferences(),
              child: const Text('Tümünü etkinleştir'),
            ),
        ],
      ),
      body: external.loadingSources && sources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : sources.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Kaynak listesi alınamadı.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: cs.onSurfaceVariant, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Kapatılan kaynaklar Canlı Haberler ekranında '
                                'gösterilmez. Sayı: ${prefs.disabledSourceCount}/${sources.length}',
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
                    ),
                    for (final s in sources)
                      _SourceTile(
                        source: s,
                        enabled: prefs.isSourceEnabled(s.id),
                        onChanged: (v) => context
                            .read<PreferencesProvider>()
                            .toggleSource(s.id, v),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.enabled,
    required this.onChanged,
  });

  final ExternalSource source;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unavailable = !source.available;
    final keyed = source.requiresApiKey;

    return SwitchListTile(
      secondary: CircleAvatar(
        backgroundColor: unavailable
            ? cs.surfaceContainerHighest
            : cs.primaryContainer.withValues(alpha: 0.7),
        child: Icon(
          unavailable
              ? Icons.lock_outline
              : (keyed ? Icons.vpn_key_outlined : Icons.rss_feed),
          size: 18,
          color: unavailable ? cs.onSurfaceVariant : cs.onPrimaryContainer,
        ),
      ),
      title: Text(source.name),
      subtitle: Text(
        unavailable
            ? 'Anahtar gerektiriyor — şu an kullanılamaz'
            : (keyed ? 'API anahtarı tabanlı' : 'RSS / açık kaynak'),
        style: const TextStyle(fontSize: 12),
      ),
      value: enabled && !unavailable,
      onChanged: unavailable ? null : onChanged,
    );
  }
}
