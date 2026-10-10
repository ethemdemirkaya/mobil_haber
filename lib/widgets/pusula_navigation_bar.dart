import 'package:flutter/material.dart';
import '../core/theme/app_icons.dart';

class PusulaNavigationBar extends StatelessWidget {
  const PusulaNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.bookmarkCount = 0,
  });
  final int selectedIndex;
  final int bookmarkCount;
  final ValueChanged<int> onSelected;
  static const _labels = ['Bugün', 'Çapraz', 'Sana özel', 'Kayıtlı', 'Ayarlar'];
  static const _icons = [
    AppIcons.home,
    AppIcons.gitCompare,
    AppIcons.adjustmentsHorizontal,
    AppIcons.bookmark,
    AppIcons.settings,
  ];
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selectedIndex,
                    button: true,
                    label: i == 3 && bookmarkCount > 0
                        ? 'Kayıtlı, $bookmarkCount haber'
                        : _labels[i],
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelected(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: i == selectedIndex
                                    ? cs.primary.withValues(alpha: .09)
                                    : Colors.transparent,
                              ),
                              child: Badge(
                                isLabelVisible: i == 3 && bookmarkCount > 0,
                                label: Text(
                                  bookmarkCount > 99 ? '99+' : '$bookmarkCount',
                                ),
                                child: Icon(
                                  _icons[i],
                                  size: 22,
                                  color: i == selectedIndex
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _labels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.25,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: i == selectedIndex
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
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
