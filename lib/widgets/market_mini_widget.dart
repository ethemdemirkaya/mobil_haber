import 'package:flutter/material.dart';

import '../data/repositories/market_widget_service.dart';

/// Brifing ekranının üstünde gösterilen "Bugün İstanbul'da hava + USD/EUR"
/// chip'i. Kompakt — header'a sığsın.
///
/// Veri için widget'ın kendi state'i yok; üst component
/// `MarketWidgetService` üzerinden veri sağlar ve bu widget render eder.
class MarketMiniWidget extends StatelessWidget {
  const MarketMiniWidget({super.key, required this.snapshot, this.onTap});

  final MarketSnapshot? snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = snapshot;
    if (s == null || !s.hasAny) {
      // Veri yok / yükleniyor — yer tutucu shimmer-tarzı.
      return Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.10),
            cs.tertiary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Row(
            children: [
              if (s.weather != null) ...[
                Text(
                  s.weather!.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.weather!.temperatureC.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    s.weather!.description,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (s.tryRates.isNotEmpty)
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
              ],
              for (final entry in s.tryRates.entries) ...[
                _Chip(
                  label: entry.key,
                  value: '₺${entry.value.toStringAsFixed(2)}',
                  color: _accentFor(entry.key),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _accentFor(String code) {
    return switch (code) {
      'USD' => Colors.green.shade700,
      'EUR' => Colors.blue.shade700,
      'GBP' => Colors.purple.shade700,
      _ => Colors.grey.shade700,
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
