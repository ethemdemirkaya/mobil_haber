import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/net/shared_http_client.dart';
import '../../core/utils/html_text.dart';
import '../models/article.dart';
import '../models/news_source.dart';
import '../repositories/category_classifier.dart';
import 'fetch_utils.dart';
import 'news_fetcher.dart';

/// WordPress REST API (`/wp-json/wp/v2/posts`) üzerinden haber listesi.
///
/// RSS'e göre: haber gövdesi (`content.rendered`), tam boy öne çıkan
/// görsel ve UTC yayın tarihi (`date_gmt`) tek istekte gelir; AI özeti
/// ve sesli okuma sayfa indirmeden tam metinle çalışır.
///
/// Belgeler: https://developer.wordpress.org/rest-api/reference/posts/
class WordPressFetcher extends NewsFetcher {
  WordPressFetcher(this.baseUrl, {http.Client? client})
      : _client = client ?? sharedHttpClient;

  /// Ör. `https://www.diken.com.tr` (sonda `/` yok).
  final String baseUrl;
  final http.Client _client;

  static const CategoryClassifier _classifier = CategoryClassifier();
  static const Duration _timeout = Duration(seconds: 10);

  @override
  String get label => 'WordPress API';

  @override
  Future<List<Article>> fetch(
    NewsSource source, {
    required int limit,
    String? category,
  }) async {
    final uri = Uri.parse('$baseUrl/wp-json/wp/v2/posts').replace(
      queryParameters: {
        'per_page': '${limit.clamp(1, 20)}',
        '_embed': 'wp:featuredmedia',
      },
    );
    final res = await _client.get(uri, headers: const {
      'User-Agent': kBrowserUserAgent,
      'Accept': 'application/json',
    }).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('WordPress API HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (decoded is! List) throw const FormatException('WordPress: liste değil');
    return decoded
        .whereType<Map>()
        .map((p) => parsePost(p, source))
        .whereType<Article>()
        .toList(growable: false);
  }

  /// Tek bir WordPress yazısını [Article]'a çevirir (test edilebilir).
  static Article? parsePost(Map post, NewsSource source) {
    final link = post['link']?.toString() ?? '';
    final title = decodeHtmlEntities(
        stripHtml(_rendered(post['title'])));
    if (link.isEmpty || title.isEmpty) return null;

    final excerpt = removePaywallTrailer(
        decodeHtmlEntities(stripHtml(_rendered(post['excerpt']))));
    final body = htmlToParagraphs(_rendered(post['content']));
    final dateGmt = post['date_gmt']?.toString();
    final published = dateGmt == null
        ? null
        : DateTime.tryParse(dateGmt.endsWith('Z') ? dateGmt : '${dateGmt}Z');

    return Article(
      id: articleIdForUrl(link),
      title: title,
      summary: excerpt.length > 320 ? '${excerpt.substring(0, 320)}…' : excerpt,
      content: body.isNotEmpty ? body : excerpt,
      categoryId: _classifier.classify(
        title: title,
        summary: excerpt,
        url: link,
        sourceDefault: source.defaultCategory,
      ),
      imageUrl: _featuredImage(post),
      author: source.name,
      publishedAt: published ?? DateTime.now(),
      readMinutes: estimateReadMinutes(body.isNotEmpty ? body : excerpt),
      sourceUrl: link,
      sourceName: source.name,
      sourceId: source.id,
    );
  }

  static String _rendered(Object? field) =>
      field is Map ? field['rendered']?.toString() ?? '' : '';

  /// `_embedded.wp:featuredmedia[0]`: önce büyük boyut, yoksa kaynak dosya.
  static String _featuredImage(Map post) {
    final embedded = post['_embedded'];
    if (embedded is! Map) return '';
    final media = embedded['wp:featuredmedia'];
    if (media is! List || media.isEmpty || media.first is! Map) return '';
    final m = media.first as Map;
    final sizes = (m['media_details'] is Map)
        ? (m['media_details'] as Map)['sizes']
        : null;
    if (sizes is Map) {
      for (final key in ['large', 'medium_large', 'td_696x0', 'full']) {
        final s = sizes[key];
        if (s is Map && s['source_url'] is String) return s['source_url'] as String;
      }
    }
    return m['source_url']?.toString() ?? '';
  }
}
