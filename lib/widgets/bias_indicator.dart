import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models/article.dart';
import '../data/models/bias_report.dart';
import '../providers/ai_settings_provider.dart';

/// Language assessment shares the article's content width at every text size.
class BiasIndicator extends StatelessWidget {
  const BiasIndicator({super.key, required this.article});
  final Article article;
  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSettingsProvider>();
    final report = ai.cachedBias(article.id);
    final loading = ai.loadingBiasId == article.id;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final error = ai.biasErrorFor(article.id);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = switch (report?.band) {
      BiasBand.neutral =>
        dark ? const Color(0xFF8DBA91) : const Color(0xFF39734A),
      BiasBand.mild => dark ? const Color(0xFFE0BB7A) : const Color(0xFF986E26),
      BiasBand.notable =>
        dark ? const Color(0xFFEAA77F) : const Color(0xFFAD582D),
      BiasBand.heavy => cs.error,
      null => cs.onSurfaceVariant,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.scale, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text('Haberin dili', style: text.titleSmall)),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (report != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  report.label,
                  style: text.labelLarge?.copyWith(color: status),
                ),
                Text(report.confidence.label, style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(report.summary, style: text.bodyMedium?.copyWith(height: 1.5)),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('Değerlendirme hakkında', style: text.bodySmall),
                children: [
                  if (report.confidence == BiasConfidence.low)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Dil sinyalleri ile yapay zeka değerlendirmesi uyuşmuyor. Sonucu temkinli yorumlayın.',
                        style: text.bodySmall,
                      ),
                    ),
                  if (report.allCues.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Tespit edilen ifadeler: ${report.allCues.join(', ')}',
                        style: text.bodyMedium,
                      ),
                    ),
                  Text(
                    'Yapay zeka yalnızca dil özelliklerini değerlendirir; haberin doğruluğunu kontrol etmez.',
                    style: text.bodySmall?.copyWith(height: 1.5),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: loading || !ai.isReady()
                          ? null
                          : () => ai.analyzeBias(article, force: true),
                      icon: const Icon(AppIcons.refresh, size: 18),
                      label: const Text('Yeniden değerlendir'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              error ??
                  (ai.isReady()
                      ? 'Manşetteki duygusal ve yönlendirici ifadeleri incele.'
                      : 'Dil değerlendirmesi için Ayarlar’dan yapay zekayı etkinleştir.'),
              style: text.bodyMedium?.copyWith(
                color: error == null ? cs.onSurfaceVariant : cs.error,
                height: 1.5,
              ),
            ),
            if (ai.isReady())
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: loading ? null : () => ai.analyzeBias(article),
                  child: Text(
                    error == null ? 'Dili değerlendir' : 'Tekrar dene',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
