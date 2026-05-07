import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  Color.alphaBlend(
                    cs.primary.withValues(alpha: 0.7),
                    cs.tertiary,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.newspaper_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppConstants.appName,
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Sürüm ${AppConstants.appVersion}${AppConstants.appBuild}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Uygulama hakkında',
            child: Text(
              'Pusula bir haber özetleyicisidir: AA, TRT, NTV, Sözcü, BBC '
              'Türkçe, DW, Euronews, Webrazzi gibi 27+ kaynaktan başlıkları '
              'birleştirir, kısa özetler halinde sunar. İsterseniz yapay zeka '
              'ile detaylı özet üretir, sesli olarak okutabilirsiniz. Tam '
              'habere ulaşmak için orijinal kaynağa tek dokunuşla atlarsınız.',
              style: textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          _Section(
            title: 'Özellikler',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet('Çok kaynaklı agregat akış (RSS + açık API\'ler)'),
                _Bullet('Detayda özet + "Orijinali oku" CTA'),
                _Bullet('Sepya okuma modu, S/M/L yazı boyutu'),
                _Bullet('Açık/koyu tema, sistem temasına otomatik uyum'),
                _Bullet('12 kategori + öne çıkanlar carousel\'i'),
                _Bullet('Anlık arama + arama geçmişi'),
                _Bullet('Yer imleri (kalıcı) + swipe-to-delete'),
                _Bullet('Okuma geçmişi ve "Devam et" satırı'),
                _Bullet('Çevrimdışı fallback (örnek veriler)'),
              ],
            ),
          ),
          _Section(
            title: 'Künye',
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.code,
                  title: 'Kaynak kodu',
                  subtitle: 'github.com/ethemdemirkaya/mobil_haber',
                ),
                _LinkTile(
                  icon: Icons.shield_outlined,
                  title: 'Gizlilik politikası',
                  subtitle: 'Cihaz dışında veri toplanmaz',
                ),
                _LinkTile(
                  icon: Icons.gavel_outlined,
                  title: 'Lisans',
                  subtitle: 'MIT (demo amaçlı)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '© 2026 Pusula',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: textTheme.bodyMedium ?? const TextStyle(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('"$title" bağlantısı sonraki sürümde'),
            behavior: SnackBarBehavior.floating,
          ));
      },
    );
  }
}
