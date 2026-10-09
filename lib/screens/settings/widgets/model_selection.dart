part of '../ai_settings_screen.dart';

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AiModelPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.5),
            width: 2,
          ),
          color: selected ? cs.primary : Colors.transparent,
        ),
        child: selected
            ? Icon(AppIcons.check, size: 14, color: cs.onPrimary)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              preset.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _tierColor(cs, preset.tier).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              preset.tier.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _tierColor(cs, preset.tier),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        preset.description,
        style: const TextStyle(fontSize: 12, height: 1.35),
      ),
    );
  }

  Color _tierColor(ColorScheme cs, AiModelTier tier) {
    return switch (tier) {
      AiModelTier.fast => Colors.green.shade700,
      AiModelTier.balanced => cs.primary,
      AiModelTier.premium => Colors.orange.shade700,
      AiModelTier.free => Colors.purple.shade700,
    };
  }
}

/// OpenRouter `/api/v1/models` endpoint'inden gelen canlı model listesi.
///
/// Üç durum:
///   1. İlk açılış (loading) → spinner
///   2. Liste hazır → "Sadece ücretsiz" filter chip'i + arama + scrollable liste
///   3. Hata → tekrar dene butonu
class _LiveModelSection extends StatefulWidget {
  const _LiveModelSection({required this.currentModelId});
  final String currentModelId;

  @override
  State<_LiveModelSection> createState() => _LiveModelSectionState();
}

class _LiveModelSectionState extends State<_LiveModelSection> {
  bool _onlyFree = true;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ai = context.watch<AiSettingsProvider>();

    final all = ai.availableModels;
    final filtered = all
        .where((m) {
          if (_onlyFree && !m.isFree) return false;
          if (_search.isEmpty) return true;
          final q = _search.toLowerCase();
          return m.id.toLowerCase().contains(q) ||
              m.name.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(
            children: [
              Text(
                'CANLI OPENROUTER LİSTESİ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (ai.modelsLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Yenile',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context
                      .read<AiSettingsProvider>()
                      .loadOpenRouterModels(forceRefresh: true),
                  icon: const Icon(AppIcons.refresh),
                ),
            ],
          ),
        ),
        if (ai.modelsError != null && all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.alertCircle, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ai.modelsError!,
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context
                        .read<AiSettingsProvider>()
                        .loadOpenRouterModels(forceRefresh: true),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          )
        else if (all.isEmpty && ai.modelsLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Canlı model listesi yükleniyor…')),
          )
        else if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Liste boş.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          )
        else ...[
          if (!ai.isCurrentModelValid)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.alertTriangle,
                      size: 16,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Şu an seçili model "${widget.currentModelId}" '
                        'OpenRouter listesinde yok — emekli edilmiş '
                        'olabilir. Aşağıdan başka bir model seçin.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    'Sadece ücretsiz (${ai.availableFreeModels.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: _onlyFree,
                  onSelected: (v) => setState(() => _onlyFree = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Ara: claude, free, gpt, gemini…',
                      prefixIcon: const Icon(AppIcons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              '${filtered.length} model gösteriliyor — '
              'liste 6 saatte bir yenilenir.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              itemBuilder: (context, i) {
                final m = filtered[i];
                final selected = m.id == widget.currentModelId;
                return _LiveModelTile(
                  model: m,
                  selected: selected,
                  onTap: () {
                    context.read<AiSettingsProvider>().setModelId(m.id);
                    HapticFeedback.selectionClick();
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveModelTile extends StatelessWidget {
  const _LiveModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final OpenRouterModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.5),
            width: 2,
          ),
          color: selected ? cs.primary : Colors.transparent,
        ),
        child: selected
            ? Icon(AppIcons.check, size: 14, color: cs.onPrimary)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              model.name.isEmpty ? model.id : model.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (model.isFree)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ÜCRETSİZ',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.purple.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else if (model.promptPricePerMillion != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                model.promptPricePerMillion!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${model.id} • ${(model.contextLength / 1000).toStringAsFixed(0)}K context',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
