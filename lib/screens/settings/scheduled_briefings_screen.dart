import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications/scheduled_briefing_service.dart';
import '../../data/models/category.dart';

/// Zamanlanmış brifing yönetim ekranı.
///
/// Kullanıcı "Sabah 7'de spor brifingi" gibi kayıtlar oluşturur. Her
/// kayıt: saat + kategori (genel veya spor/ekonomi/teknoloji vb).
/// Bildirim'e dokunulduğunda brifing ekranı açılır + kategori seçili
/// gelir + AI brifing otomatik üretilir.
class ScheduledBriefingsScreen extends StatefulWidget {
  const ScheduledBriefingsScreen({super.key});

  @override
  State<ScheduledBriefingsScreen> createState() =>
      _ScheduledBriefingsScreenState();
}

class _ScheduledBriefingsScreenState
    extends State<ScheduledBriefingsScreen> {
  List<ScheduledBriefing> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await ScheduledBriefingService.all();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _addOrEdit({ScheduledBriefing? existing}) async {
    final created = await showModalBottomSheet<ScheduledBriefing>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _BriefingEditorSheet(existing: existing),
    );
    if (created == null) return;
    HapticFeedback.lightImpact();
    final id = existing?.id ?? await ScheduledBriefingService.nextId();
    await ScheduledBriefingService.save(
      ScheduledBriefing(
        id: id,
        hour: created.hour,
        minute: created.minute,
        categoryId: created.categoryId,
        daysOfWeek: created.daysOfWeek,
        enabled: true,
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zamanlanmış Brifingler'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
        onPressed: () => _addOrEdit(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _EmptyHint(onAdd: () => _addOrEdit())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final cat = NewsCategory.byId(item.categoryId);
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: cs.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Icon(Icons.delete,
                              color: cs.onErrorContainer),
                        ),
                        onDismissed: (_) async {
                          await ScheduledBriefingService.delete(item.id);
                          await _refresh();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Brifing silindi.'),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (item.categoryId == 'all'
                                        ? cs.primary
                                        : cat.color)
                                    .withValues(alpha: 0.18),
                            child: Icon(
                              item.categoryId == 'all'
                                  ? Icons.podcasts
                                  : cat.icon,
                              color: item.categoryId == 'all'
                                  ? cs.primary
                                  : cat.color,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: item.enabled
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          subtitle: Text(item.daysLabel),
                          trailing: Switch(
                            value: item.enabled,
                            onChanged: (v) async {
                              await ScheduledBriefingService.setEnabled(
                                  item.id, v);
                              await _refresh();
                            },
                          ),
                          onTap: () => _addOrEdit(existing: item),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Zamanlanmış brifingin yok',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '"Sabah 7\'de spor brifingi" gibi kayıtlar oluştur — her gün '
            'aynı saatte bildirim gönderilir, dokunup açtığında AI brifing '
            'hazır olur.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('İlk brifingini ekle'),
          ),
        ],
      ),
    );
  }
}

class _BriefingEditorSheet extends StatefulWidget {
  const _BriefingEditorSheet({this.existing});
  final ScheduledBriefing? existing;

  @override
  State<_BriefingEditorSheet> createState() => _BriefingEditorSheetState();
}

class _BriefingEditorSheetState extends State<_BriefingEditorSheet> {
  late TimeOfDay _time;
  late String _categoryId;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _time = e == null
        ? const TimeOfDay(hour: 7, minute: 0)
        : TimeOfDay(hour: e.hour, minute: e.minute);
    _categoryId = e?.categoryId ?? 'all';
    _days = e?.daysOfWeek.toSet() ?? const {1, 2, 3, 4, 5, 6, 7}.toSet();
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    Navigator.of(context).pop(
      ScheduledBriefing(
        id: widget.existing?.id ?? -1,
        hour: _time.hour,
        minute: _time.minute,
        categoryId: _categoryId,
        daysOfWeek: _days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null
                ? 'Yeni zamanlanmış brifing'
                : 'Brifingi düzenle',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          // Saat
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Saat'),
            trailing: TextButton(
              onPressed: _pickTime,
              child: Text(
                _time.format(context),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Kategori',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Genel gündem'),
                avatar: const Icon(Icons.podcasts, size: 16),
                selected: _categoryId == 'all',
                onSelected: (_) => setState(() => _categoryId = 'all'),
              ),
              for (final c in NewsCategory.values)
                if (c.id != NewsCategory.all.id)
                  ChoiceChip(
                    label: Text(c.name),
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Günler',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 1; i <= 7; i++)
                FilterChip(
                  label: Text(_dayShort(i),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  selected: _days.contains(i),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _days.add(i);
                    } else if (_days.length > 1) {
                      _days.remove(i);
                    }
                  }),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Not: bildirim her gün aynı saatte gelir. "Sadece hafta '
              'içi" filtresi gelecek bir sürümde eklenecek.',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(widget.existing == null ? 'Kaydet' : 'Güncelle'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayShort(int i) {
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return names[i - 1];
  }
}
