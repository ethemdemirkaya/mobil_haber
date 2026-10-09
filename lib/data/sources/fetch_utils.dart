import 'dart:convert';

import '../../core/utils/html_text.dart';

/// Haber URL'sinden kararlı kimlik (FNV-1a 32 bit). RSS, WordPress API ve
/// yayıncı API'si aynı haberi aynı kimlikle üretsin diye tek yerde.
///
/// İzleme parametreleri (`utm_*`, `at_medium` …) ve parça (#…) atılır:
/// aynı haber farklı kampanya parametresiyle iki kez listelenmesin.
String articleIdForUrl(String url) {
  final bytes = utf8.encode(canonicalArticleUrl(url));
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h = (h ^ b) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return 'rss_${h.toRadixString(16).padLeft(8, '0')}';
}

const Set<String> _trackingParams = {
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'at_medium', 'at_campaign', 'at_custom1', 'at_custom2', 'at_custom3',
  'at_custom4', 'fbclid', 'gclid', 'ref', 'xtor',
};

String canonicalArticleUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return url.trim();
  final params = Map.of(uri.queryParameters)
    ..removeWhere((k, _) => _trackingParams.contains(k.toLowerCase()));
  // Not: replace(queryParameters: null) sorguyu korur; boş sorgu açıkça
  // verilmeli.
  final cleaned = params.isEmpty
      ? uri.replace(query: '', fragment: '')
      : uri.replace(queryParameters: params, fragment: '');
  return cleaned.toString().replaceFirst(RegExp(r'[?#]+$'), '');
}

/// HTML gövdeyi paragrafları koruyarak düz metne çevirir (`</p>`, `<br>`
/// ve başlık sonları paragraf sınırı sayılır).
String htmlToParagraphs(String html) {
  if (html.isEmpty) return '';
  final withBreaks = html
      .replaceAll(
          RegExp(r'<(script|style|figure|iframe)\b[^>]*>[\s\S]*?</\1\s*>',
              caseSensitive: false),
          '')
      .replaceAll(
          RegExp(r'</(p|h[1-6]|li|blockquote)>|<br\s*/?>', caseSensitive: false),
          '\n');
  return decodeHtmlEntities(withBreaks.replaceAll(RegExp(r'<[^>]*>'), ''))
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .join('\n\n');
}

/// Türkçe ortalama 200 kelime/dk; en az 1, en çok 30 dk.
int estimateReadMinutes(String text) {
  if (text.isEmpty) return 1;
  final words = text.split(RegExp(r'\s+')).length;
  return (words / 200).ceil().clamp(1, 30);
}
