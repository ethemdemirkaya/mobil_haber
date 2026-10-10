import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/net/shared_http_client.dart';
import '../../core/utils/html_text.dart';
import '../models/article.dart';
import '../models/news_source.dart';
import '../repositories/category_classifier.dart';
import 'fetch_utils.dart';
import 'news_fetcher.dart';

/// Habertürk'ün kendi kategori API'si (`htapi.haberturk.com`).
///
/// Adres, haberturk.com sayfasının kendisinin kullandığı
/// `window.sidebarNewsApi` değişkeninden alındı (tahmin edilmedi).
/// Ekim 2026'da `gundem` ve `dunya` kategorileri 200, `spor`/`ekonomi`/
/// `teknoloji` 404 döndü; diğer kategoriler RSS'e düşer.
///
/// Sınır: `spot` haberin özetidir, tam metni değildir. Tam metin
/// gerektiğinde (AI özeti) sayfa okuyucusu kullanılır.
class HaberturkFetcher extends NewsFetcher {
  HaberturkFetcher({http.Client? client}) : _client = client ?? sharedHttpClient;

  final http.Client _client;

  static const String _base =
      'https://htapi.haberturk.com/api/v1/haber/kategori/ht';
  static const CategoryClassifier _classifier = CategoryClassifier();
  static const Duration _timeout = Duration(seconds: 10);

  /// Uygulama kategorisi → doğrulanmış API kategori kodu.
  static const Map<String?, String> _categoryPaths = {
    null: 'gundem',
    'gundem': 'gundem',
    'dunya': 'dunya',
  };

  @override
  String get label => 'Habertürk API';

  @override
  bool supportsCategory(String? category) =>
      _categoryPaths.containsKey(category);

  @override
  Future<List<Article>> fetch(
    NewsSource source, {
    required int limit,
    String? category,
  }) async {
    final path = _categoryPaths[category] ?? 'gundem';
    final res = await _client.get(Uri.parse('$_base/$path'), headers: const {
      'User-Agent': kBrowserUserAgent,
      'Accept': 'application/json',
    }).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Habertürk API HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    return parseResponse(decoded, source).take(limit).toList(growable: false);
  }

  /// Yanıttaki tüm modüllerden (manşet, listeler, trend …) haberleri
  /// toplar; reklam/resmi ilanları eler, tekrarları kaldırır ve yeniden
  /// eskiye sıralar.
  static List<Article> parseResponse(Object? json, NewsSource source) {
    final byId = <int, Map>{};
    void walk(Object? n) {
      if (n is Map) {
        final id = n['newsId'];
        if (id is int && n['title'] is String) {
          final type = n['type']?.toString();
          final isAd = n['officialAdId'] != null ||
              type == 'officialAnnouncement';
          if (!isAd && (type == 'news' || type == 'photoNews')) {
            byId.putIfAbsent(id, () => n);
          }
        }
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(json);
    final articles = byId.values
        .map((n) => _toArticle(n, source))
        .whereType<Article>()
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return articles;
  }

  static Article? _toArticle(Map n, NewsSource source) {
    final url = n['absoluteUrl']?.toString() ?? '';
    final title = decodeHtmlEntities(n['title'].toString().trim());
    if (url.isEmpty || title.isEmpty) return null;
    final spot = decodeHtmlEntities(stripHtml(n['spot']?.toString() ?? ''));
    String? code;
    final cat = n['category'];
    if (cat is Map && cat['items'] is List && (cat['items'] as List).isNotEmpty) {
      final first = (cat['items'] as List).first;
      if (first is Map) code = first['kod']?.toString();
    }
    return Article(
      id: articleIdForUrl(url),
      title: title,
      summary: spot,
      content: spot,
      categoryId: _classifier.classify(
        title: title,
        summary: spot,
        rssCategories: [?code],
        url: url,
        sourceDefault: source.defaultCategory,
      ),
      imageUrl: _image(n['image']),
      author: source.name,
      publishedAt:
          parseIstanbulTime(n['updatedDateTime']?.toString()) ?? DateTime.now(),
      readMinutes: estimateReadMinutes(spot),
      sourceUrl: url,
      sourceName: source.name,
      sourceId: source.id,
    );
  }

  /// Haberlerin çoğunda manşet görseli boş (Ekim 2026: 73'te 59), ama
  /// `imageUrlBase` + boyut her haberde geçerli bir JPEG döndürüyor;
  /// 640x360 kartlar için uygun 16:9 oran.
  static String _image(Object? image) {
    if (image is! Map) return '';
    final base = image['imageUrlBase'];
    if (base is String && base.isNotEmpty) {
      return '${base.endsWith('/') ? base : '$base/'}640x360';
    }
    for (final key in ['imageUrlHeadlineDesktop', 'imageUrlHeadlineMobile']) {
      final v = image[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// "2026-10-10 00:47:44" saat dilimi taşımıyor; Türkiye saati (UTC+3,
  /// 2016'dan beri yaz saati uygulaması yok) kabul edilir.
  static DateTime? parseIstanbulTime(String? s) {
    if (s == null) return null;
    final local = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (local == null) return null;
    return DateTime.utc(local.year, local.month, local.day, local.hour,
            local.minute, local.second)
        .subtract(const Duration(hours: 3));
  }
}
