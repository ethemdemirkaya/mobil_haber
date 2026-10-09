part of '../home_screen.dart';

/// Header'daki bildirim/aksiyon butonu — daha yumuşak yuvarlatılmış
/// sürüm.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHighest;
    final fg = cs.onSurface;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Home ekranının üstünde duran arama kısayol bandı. Tek dokunuşla
/// SearchScreen'i route olarak açar (bottom-nav sekme switching'e
/// karşı: çağrı kalıcı bir route, kullanıcı geri tuşuyla dönebilir).
class _SearchShortcutBar extends StatelessWidget {
  const _SearchShortcutBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Haber, yazar veya kategori ara…',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Ana sayfa listesinin sonu: kalan haberler varsa kategori ekranına
/// götüren buton, yoksa yenile.
class _SeeAllFooter extends StatelessWidget {
  const _SeeAllFooter({
    required this.shown,
    required this.total,
    required this.onSeeAll,
    required this.onRefresh,
  });

  final int shown;
  final int total;
  final VoidCallback onSeeAll;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Center(
        child: shown < total
            ? FilledButton.tonalIcon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: Text(
                  'Tüm $total haberi gör',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              )
            : TextButton.icon(
                onPressed: onRefresh,
                icon: Icon(Icons.refresh, size: 16, color: cs.primary),
                label: const Text('Yenile'),
              ),
      ),
    );
  }
}

class _AddSourcesChip extends StatelessWidget {
  const _AddSourcesChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: cs.primary, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Düzenle',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İlk açılış sonrası, build-time gömülü API anahtarı varsa bir kez
/// yeşil bir başarı banner'ı gösterir. Kullanıcı dismiss edince bir
/// daha gözükmez.
class _AiReadyBanner extends StatelessWidget {
  const _AiReadyBanner();

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    if (!ai.shouldShowFirstRunNotice) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.16),
            Colors.green.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle,
                color: Colors.green.shade700, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yapay zeka hazır',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Brifing ve makale özetleri için ek kurulum gerekmiyor — '
                  'uygulama içi anahtar etkin.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Anladım',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                context.read<AiSettingsProvider>().markFirstRunNoticeSeen(),
          ),
        ],
      ),
    );
  }
}

/// Çevrimdışı modda — son başarılı çekimden disk cache'inden yükledik.
/// "Çevrimdışısınız" + son güncelleme zamanı + yenile.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.cachedAt, required this.onRetry});

  final DateTime? cachedAt;
  final VoidCallback onRetry;

  String _relative(DateTime? at) {
    if (at == null) return 'bilinmiyor';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Çevrimdışısınız',
                  style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Son güncellenen haberleri (${_relative(cachedAt)}) '
                  'gösteriyoruz.',
                  style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
  }
}
