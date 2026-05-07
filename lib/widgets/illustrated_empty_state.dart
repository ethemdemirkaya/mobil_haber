import 'package:flutter/material.dart';

class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = tone ?? cs.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Arka plan dairesi (yumuşak gradient)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.20),
                          accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Orbit benzeri ikinci halka
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                        width: 1.4,
                      ),
                    ),
                  ),
                  // İçerideki disk
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                    child: Icon(icon, size: 42, color: accent),
                  ),
                  // Yıldız vurguları
                  const Positioned(
                    top: 18,
                    right: 22,
                    child: _Sparkle(size: 10),
                  ),
                  const Positioned(
                    bottom: 30,
                    left: 18,
                    child: _Sparkle(size: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: cs.primary.withValues(alpha: 0.6),
    );
  }
}
