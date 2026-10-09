import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/html_text.dart';
import '../../core/utils/turkish_text.dart';

/// Makale sayfasından gövde metnini çıkaran hafif "readability" algoritması.
///
/// Çoğu Türk haber RSS'i yalnızca 1-2 cümlelik açıklama verir. AI özeti ve
/// soru-cevap bu kısa metne dayanınca model ya aynı cümleyi tekrarlıyor ya
/// da metinde olmayan bilgi uyduruyordu. Bu sınıf orijinal sayfadan
/// paragrafları çıkarır:
///
///   1. `script`, `style`, `nav`, `header`, `footer`, `aside`, `form`,
///      `figure` blokları atılır.
///   2. Sayfada `<article>` varsa en uzun olanı, yoksa tüm gövde aday bölge.
///   3. Bölgedeki her `<p>` için: düz metin ≥ [minParagraphChars], bağlantı
///      yoğunluğu (link içindeki metin / toplam) < 0.5 ve kalıp ifade
///      ("abone ol", "çerez", "tüm hakları saklıdır"…) içermiyor olmalı.
///   4. Kalan paragraflar sırayla birleştirilir; toplam [minTotalChars]
///      altındaysa çıkarım başarısız sayılır (null).
///
/// Sonuçlar uygulama yaşam süresince URL bazında bellekte tutulur.
class ArticleTextExtractor {
  ArticleTextExtractor({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);
  static const int minParagraphChars = 60;
  static const int minTotalChars = 400;
  static const int maxChars = 6000;
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; mobil_haber) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static final Map<String, String?> _cache = <String, String?>{};
  static final Map<String, Future<String?>> _inflight =
      <String, Future<String?>>{};

  /// [url]'deki makalenin gövde metni; çıkarılamazsa null.
  Future<String?> extract(String url) {
    if (url.isEmpty) return Future.value(null);
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    final pending = _inflight[url];
    if (pending != null) return pending;
    final future = _fetch(url).then((text) {
      _cache[url] = text;
      return text;
    }).whenComplete(() => _inflight.remove(url));
    _inflight[url] = future;
    return future;
  }

  Future<String?> _fetch(String url) async {
    try {
      final res = await _client.get(Uri.parse(url), headers: const {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.6',
      }).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return extractFromHtml(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  static final RegExp _noise = RegExp(
    r'<(script|style|noscript|nav|header|footer|aside|form|figure|iframe)'
    r'\b[^>]*>[\s\S]*?</\1\s*>',
    caseSensitive: false,
  );
  static final RegExp _comment = RegExp(r'<!--[\s\S]*?-->');
  static final RegExp _article = RegExp(
    r'<article\b[^>]*>([\s\S]*?)</article\s*>',
    caseSensitive: false,
  );
  static final RegExp _body = RegExp(
    r'<body\b[^>]*>([\s\S]*)</body\s*>',
    caseSensitive: false,
  );
  static final RegExp _paragraph = RegExp(
    r'<p\b[^>]*>([\s\S]*?)</p\s*>',
    caseSensitive: false,
  );
  static final RegExp _anchor = RegExp(
    r'<a\b[^>]*>([\s\S]*?)</a\s*>',
    caseSensitive: false,
  );

  /// Kalıp/boilerplate paragrafları ele veren ifadeler ([foldTr] biçiminde).
  static const List<String> _boilerplate = [
    'abone ol', 'cerez', 'tum haklari', 'kvkk', 'kisisel verilerin',
    'yorum yap', 'yorumlar', 'ilgili haber', 'devamini oku',
    'haberin devami', 'tiklayin', 'tiklayiniz', 'reklam', 'bizi takip',
    'uygulamamizi indir', 'e-bulten', 'izinsiz kullanilamaz',
    'kaynak gosterilmeden',
  ];

  /// HTML'den gövde metnini çıkarır. Test edilebilsin diye ağdan bağımsız.
  static String? extractFromHtml(String html) {
    final cleaned = html.replaceAll(_comment, '').replaceAll(_noise, '');

    var region = '';
    for (final m in _article.allMatches(cleaned)) {
      final candidate = m.group(1) ?? '';
      if (candidate.length > region.length) region = candidate;
    }
    if (region.isEmpty) {
      region = _body.firstMatch(cleaned)?.group(1) ?? cleaned;
    }

    final paragraphs = <String>[];
    var total = 0;
    for (final m in _paragraph.allMatches(region)) {
      final inner = m.group(1) ?? '';
      final text = decodeHtmlEntities(stripHtml(inner));
      if (text.length < minParagraphChars) continue;

      var linkChars = 0;
      for (final a in _anchor.allMatches(inner)) {
        linkChars += stripHtml(a.group(1) ?? '').length;
      }
      if (linkChars / text.length >= 0.5) continue;

      final folded = foldTr(text);
      if (_boilerplate.any(folded.contains)) continue;

      paragraphs.add(text);
      total += text.length;
      if (total >= maxChars) break;
    }

    if (total < minTotalChars) return null;
    final joined = paragraphs.join('\n\n');
    return joined.length > maxChars ? joined.substring(0, maxChars) : joined;
  }
}
