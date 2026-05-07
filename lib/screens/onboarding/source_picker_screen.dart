import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/news_source.dart';
import '../../providers/news_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/preferences_provider.dart';
import '../main_navigation.dart';

/// Onboarding'in son adımı — kullanıcı kullanmak istediği haber
/// kaynaklarını seçer. Buradaki seçim `PreferencesProvider`'a kalıcı
/// yazılır ve `NewsProvider.applySources` ile ana akışı tetikler.
class SourcePickerScreen extends StatefulWidget {
  const SourcePickerScreen({
    super.key,
    this.standalone = false,
    this.title,
  });

  /// Onboarding akışında değil de "Ayarlar > Kaynak Tercihleri" altında
  /// açıldıysa AppBar gösterilir ve "Devam" yerine "Kaydet" butonu olur.
  final bool standalone;
  final String? title;

  @override
  State<SourcePickerScreen> createState() => _SourcePickerScreenState();
}

class _SourcePickerScreenState extends State<SourcePickerScreen> {
  late Set<String> _selected;
  bool _initialized = false;

  static const Color _bg = Color(0xFF7C3AED);
  static const Color _bg2 = Color(0xFFA78BFA);

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

  Future<void> _finish() async {
    if (_selected.isEmpty) {
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
    // applySources `_load` çağırır — ana ekrana geldiğinde shimmer
    // yerine canlı haberler hazır olur.
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
    if (widget.standalone) {
      return _buildStandalone(context);
    }
    return _buildOnboarding(context);
  }

  Widget _buildOnboarding(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bg2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hangi kaynaklardan\nokumak istersin?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seçtiğin kaynaklardan gelen başlıkları birleştirip '
                      'tek akışta sunarız. İstediğin zaman ayarlardan '
                      'değiştirebilirsin.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _SourceList(
                  selected: _selected,
                  onToggle: _toggle,
                  light: false,
                ),
              ),
              _BottomBar(
                onContinue: _finish,
                count: _selected.length,
                label: 'Başla',
                onSelectAll: () => setState(() {
                  _selected
                    ..clear()
                    ..addAll(NewsSourceCatalog.all.map((s) => s.id));
                }),
                onClear: () => setState(() => _selected.clear()),
                light: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandalone(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Kaynak Tercihleri'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selected
                  ..clear()
                  ..addAll(NewsSourceCatalog.recommendedIds);
              });
            },
            child: const Text('Önerileni seç'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _SourceList(
              selected: _selected,
              onToggle: _toggle,
              light: true,
            ),
          ),
          _BottomBar(
            onContinue: _finish,
            count: _selected.length,
            label: 'Kaydet',
            onSelectAll: () => setState(() {
              _selected
                ..clear()
                ..addAll(NewsSourceCatalog.all.map((s) => s.id));
            }),
            onClear: () => setState(() => _selected.clear()),
            light: true,
          ),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.selected,
    required this.onToggle,
    required this.light,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = light ? cs.surface : Colors.white;
    final fg = light ? cs.onSurface : Colors.black;
    final muted = light ? cs.onSurfaceVariant : Colors.black54;

    return Container(
      margin: light
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: light ? BorderRadius.zero : BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: NewsSourceCatalog.all.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: muted.withValues(alpha: 0.18),
          indent: 76,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final s = NewsSourceCatalog.all[index];
          final isSelected = selected.contains(s.id);
          return _SourceTile(
            source: s,
            selected: isSelected,
            fg: fg,
            muted: muted,
            onTap: () => onToggle(s.id),
          );
        },
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.selected,
    required this.fg,
    required this.muted,
    required this.onTap,
  });

  final NewsSource source;
  final bool selected;
  final Color fg;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            _SourceLogo(source: source, size: 44),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          source.name,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (source.recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: source.brandColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'önerilen',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: source.brandColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PickIndicator(selected: selected, color: source.brandColor),
          ],
        ),
      ),
    );
  }
}

class _SourceLogo extends StatelessWidget {
  const _SourceLogo({required this.source, required this.size});
  final NewsSource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: source.brandColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        source.shortName.isNotEmpty
            ? source.shortName.substring(0, 1).toUpperCase()
            : '?',
        style: TextStyle(
          color: source.brandColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: source.brandColor.withValues(alpha: 0.10),
        child: CachedNetworkImage(
          imageUrl: source.logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected
              ? color
              : Colors.black.withValues(alpha: 0.25),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onContinue,
    required this.count,
    required this.label,
    required this.onSelectAll,
    required this.onClear,
    required this.light,
  });

  final VoidCallback onContinue;
  final int count;
  final String label;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = light ? cs.onSurface : Colors.white;
    final action = light ? cs.primary : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$count seçili',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(foregroundColor: action),
                child: const Text('Tümü'),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(foregroundColor: action),
                child: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: light ? cs.primary : Colors.white,
                foregroundColor: light ? cs.onPrimary : const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
