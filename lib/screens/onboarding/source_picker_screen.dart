import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/news_source.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../widgets/pusula_glyph.dart';
import '../../widgets/source_logo.dart';
import '../main_navigation.dart';

/// Onboarding'in son adımı — kullanıcı kullanmak istediği haber
/// kaynaklarını seçer. Buradaki seçim `PreferencesProvider`'a kalıcı
/// yazılır ve `NewsProvider.applySources` ile ana akışı tetikler.
///
/// Tasarım: Splash + onboarding ile aynı tema-uyumlu surface dili.
/// Eski mor (#7C3AED) gradient yerine theme.surface üzerine brand-renk
/// vurgular. Kaynaklar "Önerilen" ve "Diğer" olarak iki segmentte.
class SourcePickerScreen extends StatefulWidget {
  const SourcePickerScreen({
    super.key,
    this.standalone = false,
    this.title,
  });

  /// "Ayarlar > Kaynak Tercihleri" altında açıldıysa AppBar gösterilir
  /// ve "Devam" yerine "Kaydet" butonu olur.
  final bool standalone;
  final String? title;

  @override
  State<SourcePickerScreen> createState() => _SourcePickerScreenState();
}

class _SourcePickerScreenState extends State<SourcePickerScreen> {
  late Set<String> _selected;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final prefs = context.read<PreferencesProvider>();
    _selected = prefs.selectedSources.isEmpty
        ? NewsSourceCatalog.recommendedIds.toSet()
        : Set<String>.from(prefs.selectedSources);
    _initialized = true;
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectRecommended() {
    HapticFeedback.lightImpact();
    setState(() {
      _selected
        ..clear()
        ..addAll(NewsSourceCatalog.recommendedIds);
    });
  }

  void _selectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _selected
        ..clear()
        ..addAll(NewsSourceCatalog.all.map((s) => s.id));
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() => _selected.clear());
  }

  Future<void> _finish() async {
    if (_selected.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('En az bir kaynak seçmelisin.'),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final prefs = context.read<PreferencesProvider>();
    final news = context.read<NewsProvider>();
    final onboarding =
        widget.standalone ? null : context.read<OnboardingProvider>();
    await prefs.setSelectedSources(_selected);
    if (onboarding != null) {
      await onboarding.complete();
    }
    // ignore: unawaited_futures
    news.applySources(prefs.effectiveSources);
    if (!mounted) return;
    if (widget.standalone) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => const MainNavigation(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final recommended =
        NewsSourceCatalog.all.where((s) => s.recommended).toList();
    final others =
        NewsSourceCatalog.all.where((s) => !s.recommended).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: widget.standalone
          ? AppBar(
              title: Text(widget.title ?? 'Kaynak Tercihleri'),
              actions: [
                IconButton(
                  tooltip: 'Önerilenleri seç',
                  onPressed: _selectRecommended,
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
              ],
            )
          : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
        child: SafeArea(
          top: !widget.standalone,
          child: Column(
            children: [
              if (!widget.standalone) _Hero(selectedCount: _selected.length),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Hızlı eylem chip'leri (sticky değil — sadece üstte).
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: _QuickActions(
                          onRecommended: _selectRecommended,
                          onAll: _selectAll,
                          onClear: _clearAll,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Önerilen',
                        subtitle:
                            'Pusula\'nın günlük kullanım için seçtiği denge.',
                        accent: cs.primary,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverList.separated(
                        itemCount: recommended.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = recommended[i];
                          return _SourceTile(
                            source: s,
                            selected: _selected.contains(s.id),
                            onTap: () => _toggle(s.id),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        icon: Icons.list_alt_rounded,
                        title: 'Diğer kaynaklar',
                        subtitle:
                            'Niş veya bölgesel — istersen ekleyebilirsin.',
                        accent: cs.tertiary,
                      ),
                    ),
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: others.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = others[i];
                          return _SourceTile(
                            source: s,
                            selected: _selected.contains(s.id),
                            onTap: () => _toggle(s.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                count: _selected.length,
                ctaLabel: widget.standalone ? 'Kaydet' : 'Başla',
                onContinue: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.selectedCount});
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand bar — onboarding ile aynı.
          Row(
            children: [
              PusulaGlyph(
                size: 28,
                showRim: false,
                foreground: cs.primary,
                background: cs.surface,
                muted: cs.onSurfaceVariant,
                accent: cs.outline,
              ),
              const SizedBox(width: 10),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  '03 / 03',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Hangi kaynaklardan\nokumak istersin?',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              height: 1.15,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçtiklerinden gelen başlıkları birleştirir, '
            'çoklu yayını gündem altında gruplarız. Her zaman '
            'Ayarlar\'dan değiştirebilirsin.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onRecommended,
    required this.onAll,
    required this.onClear,
  });
  final VoidCallback onRecommended;
  final VoidCallback onAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionPill(
            icon: Icons.auto_awesome_outlined,
            label: 'Önerilen',
            onTap: onRecommended,
            accent: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.select_all_rounded,
            label: 'Tümü',
            onTap: onAll,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.refresh_rounded,
            label: 'Temizle',
            onTap: onClear,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = accent ? cs.primary : cs.onSurfaceVariant;
    final bg = accent
        ? cs.primary.withValues(alpha: 0.10)
        : cs.surfaceContainerHighest;
    final border = accent
        ? cs.primary.withValues(alpha: 0.28)
        : cs.outlineVariant.withValues(alpha: 0.5);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.1,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final NewsSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = source.brandColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? brand.withValues(alpha: 0.08)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? brand.withValues(alpha: 0.45)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                SourceLogo(source: source, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        source.name,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _PickIndicator(selected: selected, color: brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickIndicator extends StatelessWidget {
  const _PickIndicator({required this.selected, required this.color});
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected
              ? color
              : cs.outline.withValues(alpha: 0.55),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : null,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.ctaLabel,
    required this.onContinue,
  });

  final int count;
  final String ctaLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final disabled = count == 0;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          // Sayım badge — küçük yuvarlak rozet.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: disabled
                  ? cs.surfaceContainerHighest
                  : cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: disabled
                    ? cs.outlineVariant.withValues(alpha: 0.5)
                    : cs.primary.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: disabled ? cs.onSurfaceVariant : cs.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: tt.labelLarge?.copyWith(
                    color: disabled ? cs.onSurfaceVariant : cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'seçili',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: disabled ? 0.6 : 1.0,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: disabled
                      ? cs.surfaceContainerHighest
                      : cs.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: disabled
                      ? null
                      : [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: disabled ? null : onContinue,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ctaLabel,
                            style: TextStyle(
                              color: disabled ? cs.onSurfaceVariant : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: disabled
                                ? cs.onSurfaceVariant
                                : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
