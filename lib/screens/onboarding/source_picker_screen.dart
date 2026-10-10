import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/news_source.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/source_logo.dart';
import 'notification_intro_screen.dart';

class SourcePickerScreen extends StatefulWidget {
  const SourcePickerScreen({super.key, this.standalone = false, this.title});
  final bool standalone;
  final String? title;
  @override
  State<SourcePickerScreen> createState() => _SourcePickerScreenState();
}

class _SourcePickerScreenState extends State<SourcePickerScreen> {
  final _search = TextEditingController();
  Set<String>? _selected;
  bool _saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = context.read<PreferencesProvider>();
    _selected ??= prefs.selectedSources.isEmpty
        ? NewsSourceCatalog.recommendedIds.toSet()
        : {...prefs.selectedSources};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _selected!.isEmpty) return;
    setState(() => _saving = true);
    final prefs = context.read<PreferencesProvider>();
    final news = context.read<NewsProvider>();
    try {
      await prefs.setSelectedSources(_selected!);
      news.applySources(prefs.effectiveSources);
      if (!mounted) return;
      if (widget.standalone) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationIntroScreen(),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tercihler kaydedilemedi. Yeniden dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = _search.text.trim().toLowerCase();
    final sources =
        NewsSourceCatalog.all
            .where((s) => '${s.name} ${s.shortName}'.toLowerCase().contains(q))
            .toList()
          ..sort(
            (a, b) => a.recommended == b.recommended
                ? a.name.compareTo(b.name)
                : (a.recommended ? -1 : 1),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.standalone ? 'Kaynak tercihleri' : 'Kaynakların'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.standalone) ...[
                  Text(
                    'Gündemi kimden\ntakip edelim?',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Farklı kaynaklar, daha geniş bir bakış. İstediğin zaman değiştirebilirsin.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Kaynak ara',
                    prefixIcon: const Icon(AppIcons.search),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(AppIcons.x),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setState(
                        () => _selected = NewsSourceCatalog.recommendedIds
                            .toSet(),
                      ),
                      child: const Text('Önerilenler'),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _selected = NewsSourceCatalog.all
                            .map((s) => s.id)
                            .toSet(),
                      ),
                      child: const Text('Tümünü seç'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selected!.clear()),
                      child: const Text('Temizle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: sources.isEmpty
                ? Center(
                    child: Text(
                      'Bu isimde kaynak bulunamadı.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
                        mainAxisExtent:
                            132 +
                            (MediaQuery.textScalerOf(context).scale(14) - 14) *
                                3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: sources.length,
                      itemBuilder: (context, i) {
                        final s = sources[i];
                        final selected = _selected!.contains(s.id);
                        return Semantics(
                          selected: selected,
                          child: Material(
                            color: selected
                                ? cs.primaryContainer
                                : cs.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: selected
                                    ? cs.primary
                                    : cs.outlineVariant,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() {
                                if (selected) {
                                  _selected!.remove(s.id);
                                } else {
                                  _selected!.add(s.id);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SourceLogo(
                                          source: s,
                                          size: 32,
                                          borderRadius: 6,
                                        ),
                                        const Spacer(),
                                        Icon(
                                          selected
                                              ? AppIcons.circleCheck
                                              : AppIcons.circle,
                                          size: 20,
                                          color: selected
                                              ? cs.primary
                                              : cs.outline,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      s.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.recommended
                                          ? 'Önerilen kaynak'
                                          : s.domain,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _selected!.isEmpty
                    ? 'Devam etmek için en az bir kaynak seç.'
                    : '${_selected!.length} kaynak seçildi',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _saving || _selected!.isEmpty ? null : _save,
                child: Text(
                  _saving
                      ? 'Kaydediliyor…'
                      : widget.standalone
                      ? 'Değişiklikleri kaydet'
                      : 'Devam et',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
