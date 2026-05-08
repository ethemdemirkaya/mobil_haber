import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/article.dart';
import '../data/models/bias_report.dart';
import '../providers/ai_settings_provider.dart';

/// Detay ekranında AI yönlülük analizini gösteren kart.
///
/// İlk açıldığında "Analiz et" butonu — tıklayınca OpenRouter'a sorulur,
/// JSON parse edilir, kalıcı cache'e yazılır. Sonraki açılışlarda direkt
/// renk kodlu skor + cue chip listesi.
class BiasIndicator extends StatelessWidget {
  const BiasIndicator({
    super.key,
    required this.article,
  });

  final Article article;

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final report = ai.cachedBias(article.id);
    final loading = ai.loadingBiasId == article.id;

    if (report != null) {
      return _BiasReportCard(article: article, report: report);
    }
    return _BiasPromptCard(loading: loading, article: article);
  }
}

class _BiasPromptCard extends StatelessWidget {
  const _BiasPromptCard({
    required this.loading,
    required this.article,
  });

  final bool loading;
  final Article article;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ai = context.watch<AiSettingsProvider>();
    final disabled = !ai.isReady() && !loading;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.balance, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yönlülük Analizi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disabled
                      ? 'AI kapalı — Ayarlar > Yapay Zeka'
                      : 'Manşet dilinin tarafsızlığını AI ile değerlendir',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : FilledButton.tonal(
                  onPressed: disabled
                      ? null
                      : () =>
                          context.read<AiSettingsProvider>().analyzeBias(article),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Analiz et'),
                ),
        ],
      ),
    );
  }
}

class _BiasReportCard extends StatelessWidget {
  const _BiasReportCard({required this.article, required this.report});

  final Article article;
  final BiasReport report;

  Color _bandColor(BiasBand b) => switch (b) {
        BiasBand.neutral => const Color(0xFF2E7D32),
        BiasBand.mild => const Color(0xFFF9A825),
        BiasBand.notable => const Color(0xFFE65100),
        BiasBand.heavy => const Color(0xFFC62828),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bandColor = _bandColor(report.band);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bandColor.withValues(alpha: 0.14),
            bandColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bandColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance, color: bandColor, size: 18),
              const SizedBox(width: 6),
              Text(
                'Yönlülük: ${report.label}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: bandColor,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bandColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${report.score}/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Skor barı — 0..100
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (report.score / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: bandColor.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(bandColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            report.summary,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: cs.onSurface,
            ),
          ),
          if (report.cues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'TESPİT EDİLEN İFADELER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cue in report.cues)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: bandColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '"$cue"',
                      style: TextStyle(
                        fontSize: 11,
                        color: bandColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Sadece dil özellikleri değerlendirilir, olgu doğruluğu '
                  'kontrol edilmez.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context
                    .read<AiSettingsProvider>()
                    .analyzeBias(article, force: true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Yenile',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
