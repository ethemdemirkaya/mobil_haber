import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/keyword_filter_provider.dart';

/// Kullanıcının ilgi duyduğu anahtar kelimeleri yönettiği ekran.
///
/// Eklenen kelimeler:
///   - Ana sayfa kartlarında "İlgi" rozeti olarak vurgulanır.
///   - Kişiselleştirilmiş feed'in filtresinde kullanılır.
///   - "Eşleşmede bildir" açıksa, push notif sistemi (zamanlanmış brifing
///     + ileride FCM) match edenlerde uyarır.
class KeywordFiltersScreen extends StatefulWidget {
  const KeywordFiltersScreen({super.key});

  @override
  State<KeywordFiltersScreen> createState() => _KeywordFiltersScreenState();
}

class _KeywordFiltersScreenState extends State<KeywordFiltersScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const List<String> _suggestions = [
    'Galatasaray',
    'Fenerbahçe',
    'Beşiktaş',
    'Bitcoin',
    'Faiz',
    'Yapay zeka',
    'İklim',
    'Uzay',
    'Seçim',
    'Deprem',
  ];

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.selectionClick();
    await context.read<KeywordFilterProvider>().add(trimmed);
    _input.clear();
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filter = context.watch<KeywordFilterProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anahtar Kelime Filtreleri'),
        actions: [
          if (filter.hasKeywords)
            IconButton(
              tooltip: 'Tümünü temizle',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await _confirm(context);
                if (ok && context.mounted) {
                  // ignore: use_build_context_synchronously
                  context.read<KeywordFilterProvider>().clear();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Kullanım kartı ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.14),
                  cs.tertiary.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'İlgi duyduğun kelimeleri ekle. Eşleşen haberler '
                    'ana sayfada vurgulanır ve "Sana Özel" akışına '
                    'düşer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Giriş alanı ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _input,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Örn: Galatasaray, FED, Bitcoin',
                prefixIcon: const Icon(Icons.add_circle_outline),
                suffixIcon: _input.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _add(_input.text),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _add,
            ),
          ),

          // ── Önerilen kelimeler chip'leri ──
          if (filter.count < 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    final already = filter.keywords.any(
                      (k) => k.toLowerCase() == s.toLowerCase(),
                    );
                    return ActionChip(
                      label: Text(s,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      avatar: Icon(
                        already ? Icons.check : Icons.add,
                        size: 14,
                        color: already
                            ? Colors.green.shade700
                            : cs.onSurfaceVariant,
                      ),
                      onPressed: already ? null : () => _add(s),
                    );
                  },
                ),
              ),
            ),

          const Divider(height: 1),

          // ── Bildirim toggle ──
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Eşleşmelerde bildir'),
            subtitle: const Text(
              'Yeni bir haber eşleştiğinde push bildirimi gönderilsin.',
            ),
            value: filter.notifyOnMatch,
            onChanged: (v) =>
                context.read<KeywordFilterProvider>().setNotifyOnMatch(v),
          ),
          const Divider(height: 1),

          // ── Mevcut kelimeler ──
          Expanded(
            child: filter.keywords.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Henüz anahtar kelime yok.\n'
                        'Yukarıdaki kutudan ekleyin veya bir öneriyi seçin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filter.keywords.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                      indent: 56,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, i) {
                      final k = filter.keywords[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.14),
                          child: Icon(Icons.tag,
                              color: cs.primary, size: 18),
                        ),
                        title: Text(k,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        trailing: IconButton(
                          icon: Icon(Icons.close,
                              color: cs.onSurfaceVariant),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.read<KeywordFilterProvider>().remove(k);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anahtar kelimeleri temizle'),
        content: const Text('Tüm filtreler silinecek.'),
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
}
