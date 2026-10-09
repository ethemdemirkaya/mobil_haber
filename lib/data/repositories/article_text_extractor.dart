import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/net/shared_http_client.dart';
import '../../core/utils/html_text.dart';
import '../../core/utils/turkish_text.dart';

/// Makale sayfasından gövde metnini çıkaran hafif "readability" algoritması.
///
/// Çoğu Türk haber RSS'i yalnızca 1-2 cümlelik açıklama verir. AI özeti ve
/// soru-cevap bu kısa metne dayanınca model ya aynı cümleyi tekrarlıyor ya
/// da metinde olmayan bilgi uyduruyordu. Bu sınıf orijinal sayfadan
/// gövde metnini çıkarır:
///
///   0. Önce yapılandırılmış veri: haber siteleri arama motorları için
///      `<script type="application/ld+json">` içinde schema.org
///      `NewsArticle.articleBody` yayınlar (AA, Sabah…). Varsa en
///      güvenilir kaynak budur.
///   1. Yoksa `script`, `style`, `nav`, `header`, `footer`, `aside`, `form`,
///      `figure` blokları atılır.
///   2. Sayfada `<article>` varsa en uzun olanı, yoksa tüm gövde aday bölge.
///   3. Bölgedeki her `<p>` için: düz metin ≥ [minParagraphChars], bağlantı
///      yoğunluğu (link içindeki metin / toplam) < 0.5 ve kalıp ifade
///      ("abone ol", "çerez", "tüm hakları saklıdır"…) içermiyor olmalı.
///   4. Kalan paragraflar sırayla birleştirilir; toplam [minTotalChars]
///      altındaysa çıkarım başarısız sayılır (null).
///
/// Sonuçlar uygulama yaşam süresince URL bazında bellekte tutulur. Otomatik
/// erişimi reddeden siteler (401/403/429) oturum boyunca hatırlanır ve o
/// siteye tekrar istek atılmaz — [isBlocked] ile sorgulanabilir.
class ArticleTextExtractor {
  ArticleTextExtractor({http.Client? client})
      : _client = client ?? sharedHttpClient;

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);
  static const int minParagraphChars = 60;
  static const int minTotalChars = 400;

  /// Yapılandırılmış `articleBody` yayıncının kendi gövde metnidir; kısa
  /// haberlerde de (ör. Sabah ~390 karakter) güvenilir olduğu için eşik
  /// paragraf taramasından düşüktür.
  static const int minStructuredChars = 200;
  static const int maxChars = 6000;
  static const String _userAgent = kBrowserUserAgent;

  static final Map<String, String?> _cache = <String, String?>{};
  static final Map<String, Future<String?>> _inflight =
      <String, Future<String?>>{};
  static final Set<String> _blockedHosts = <String>{};

  /// [url]'nin sitesi otomatik erişimi reddetti mi? (Ör. Cloudflare
  /// korumalı tr.investing.com 403 döndürüyor.)
  bool isBlocked(String url) =>
      _blockedHosts.contains(Uri.tryParse(url)?.host ?? '');

  /// [url]'deki makalenin gövde metni; çıkarılamazsa null.
  Future<String?> extract(String url) {
    if (url.isEmpty || isBlocked(url)) return Future.value(null);
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    final pending = _inflight[url];
    if (pending != null) return pending;
    final future = _fetch(url).then((text) {
      _cache[url] = text;
      return text;
    }).whenComplete(() {
      // Blok gövde bilinçli: `=> _inflight.remove(url)` silinen Future'ı
      // döndürür ve whenComplete onu da bekler — Future kendini bekleyip
      // sonsuza kadar asılı kalıyordu.
      _inflight.remove(url);
    });
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
      if (const {401, 403, 429}.contains(res.statusCode)) {
        _blockedHosts.add(Uri.parse(url).host);
        return null;
      }
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

  static final RegExp _jsonLd = RegExp(
    r'''<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script\s*>''',
    caseSensitive: false,
  );

  /// JSON-LD bloklarındaki en uzun `articleBody`; yoksa null.
  static String? _articleBodyFromJsonLd(String html) {
    String? best;
    void visit(Object? node) {
      if (node is List) {
        node.forEach(visit);
      } else if (node is Map) {
        final body = node['articleBody'];
        if (body is String && body.length > (best?.length ?? 0)) best = body;
        node.values.whereType<Object>().forEach(visit);
      }
    }

    for (final m in _jsonLd.allMatches(html)) {
      try {
        visit(jsonDecode(m.group(1)!.trim()));
      } on FormatException {
        // Bozuk JSON-LD bloğu: atla.
      }
    }
    if (best == null) return null;
    // Bazı siteler articleBody içine HTML koyuyor; paragraf sınırlarını
    // koruyarak düz metne çevir.
    final text = decodeHtmlEntities(best!
            .replaceAll(RegExp(r'</p>|<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'<[^>]*>'), ''))
        .split(RegExp(r'\s*\n\s*'))
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .join('\n\n');
    return text;
  }

  /// HTML'den gövde metnini çıkarır. Test edilebilsin diye ağdan bağımsız.
  static String? extractFromHtml(String html) {
    final structured = _articleBodyFromJsonLd(html);
    if (structured != null && structured.length >= minStructuredChars) {
      return structured.length > maxChars
          ? structured.substring(0, maxChars)
          : structured;
    }

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
