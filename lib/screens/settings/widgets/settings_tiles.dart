part of '../ai_settings_screen.dart';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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

/// Aktif anahtar modunun durumunu gösteren bilgi/uyarı kartı.
/// 4 durum:
///   - builtIn + env var → yeşil "Pusula varsayılan anahtarı aktif"
///   - builtIn + env yok → kırmızı "Varsayılan anahtar yok, kendi anahtarına geç"
///   - userProvided + key var → mavi "Kişisel anahtar aktif"
///   - userProvided + key yok → turuncu "Anahtarını gir"
class _ApiKeyModeStatus extends StatelessWidget {
  const _ApiKeyModeStatus({
    required this.mode,
    required this.hasBuiltIn,
    required this.hasUserKey,
  });

  final ApiKeyMode mode;
  final bool hasBuiltIn;
  final bool hasUserKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, accent, text) = _resolve(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _resolve(ColorScheme cs) {
    switch (mode) {
      case ApiKeyMode.builtIn:
        if (hasBuiltIn) {
          return (
            Icons.verified_outlined,
            Colors.green.shade700,
            'Varsayılan anahtar aktif — uygulama içi gömülü OpenRouter '
                'anahtarını kullanıyor. Senin için kullanım limiti '
                'paylaşılır.',
          );
        }
        return (
          Icons.warning_amber_rounded,
          Colors.red.shade700,
          'Bu sürümde varsayılan anahtar yok. "Kendi anahtarım" moduna '
              'geçip OpenRouter anahtarını gir.',
        );
      case ApiKeyMode.userProvided:
        if (hasUserKey) {
          return (
            Icons.person_outline,
            cs.primary,
            'Kişisel API anahtarın aktif — kendi rate-limit ve '
                'faturalandırman kullanılıyor.',
          );
        }
        return (
          Icons.error_outline,
          Colors.orange.shade700,
          'Anahtarın boş. Aşağıdaki kutuya OpenRouter anahtarını yapıştır '
              've "Kaydet"e bas.',
        );
    }
  }
}

class _AudioCacheTile extends StatefulWidget {
  const _AudioCacheTile();

  @override
  State<_AudioCacheTile> createState() => _AudioCacheTileState();
}

class _AudioCacheTileState extends State<_AudioCacheTile> {
  CacheStats? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final s = await BriefingAudioCache.stats();
    if (!mounted) return;
    setState(() => _stats = s);
  }

  Future<void> _clear() async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final removed = await BriefingAudioCache.clear();
    await _refreshStats();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('$removed adet ses dosyası silindi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final subtitle = s == null
        ? 'Yükleniyor…'
        : (s.count == 0
            ? 'Boş — henüz cache\'lenmiş ses yok.'
            : '${s.count} dosya · ${s.humanSize}');
    return ListTile(
      leading: const Icon(Icons.audiotrack_outlined),
      title: const Text('OpenAI TTS ses önbelleği'),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (s == null || s.count == 0
              ? null
              : TextButton(
                  onPressed: _clear,
                  child: const Text('Temizle'),
                )),
    );
  }
}

class _SimpleRadioTile extends StatelessWidget {
  const _SimpleRadioTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
            ? Icon(Icons.check, size: 14, color: cs.onPrimary)
            : null,
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, height: 1.35)),
    );
  }
}

class _TtsEngineTile extends StatelessWidget {
  const _TtsEngineTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final TtsEngineKind kind;
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
            ? Icon(Icons.check, size: 14, color: cs.onPrimary)
            : null,
      ),
      title: Row(
        children: [
          Icon(
            switch (kind) {
              TtsEngineKind.system => Icons.smartphone_outlined,
              TtsEngineKind.openai => Icons.cloud_outlined,
              TtsEngineKind.elevenlabs => Icons.graphic_eq,
              TtsEngineKind.edge => Icons.language_outlined,
            },
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              kind.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      subtitle: Text(
        kind.description,
        style: const TextStyle(fontSize: 12, height: 1.35),
      ),
    );
  }
}
