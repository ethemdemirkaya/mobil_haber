import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Görsel olmayan haberler için, makale URL'inden OpenGraph `og:image`
/// meta etiketini çekip görseli sağlayan lazy resolver.
///
/// Bazı RSS feed'leri (Diken, Independent Türkçe, Euronews Türkçe, Evrensel
/// vs) makale görselini RSS payload'una koymuyor; sadece link veriyorlar.
/// Bu durumda gerçek görseli almak için makale sayfasının HTML'ini çekip
/// `<meta property="og:image" content="...">` etiketini parse ediyoruz.
///
/// Performans:
///   - In-memory cache (`articleUrl → imageUrl?`).
///   - Aynı URL için eşzamanlı isteğe inflight tracking (deduplication).
///   - Tek HTTP timeout 5 sn.
///   - Sadece makalenin ilk ~32 KB'i indiriliyor (`<head>` orada bitmiş olur).
///
/// Bellek temizliği yapmıyor — cache uygulama yaşam süresince büyür ama
/// her kayıt küçük (~80 byte). Tipik kullanım için OK.
class OgImageResolver {
  OgImageResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 5);
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; mobil_haber) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  // Process-genelinde tek cache — ArticleImage widget'ları paylaşıyor.
  static final Map<String, String?> _cache = <String, String?>{};
  static final Map<String, Future<String?>> _inflight =
      <String, Future<String?>>{};

  /// `articleUrl`'den og:image çıkar; cache'lenmişse hemen döner. Hata
  /// durumunda null. Aynı anda iki widget aynı URL'yi sorarsa tek HTTP atılır.
  Future<String?> resolve(String articleUrl) {
    if (articleUrl.isEmpty) return Future.value(null);
    if (_cache.containsKey(articleUrl)) {
      return Future.value(_cache[articleUrl]);
    }
    final inflight = _inflight[articleUrl];
    if (inflight != null) return inflight;

    final future = _fetchAndExtract(articleUrl).whenComplete(() {
      _inflight.remove(articleUrl);
    });
    _inflight[articleUrl] = future;
    return future;
  }

  Future<String?> _fetchAndExtract(String url) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: const {
              'User-Agent': _userAgent,
              // Yalnızca <head>'i indirmek istiyoruz — Range header bazı
              // sunucularda saygı görmüyor ama denenmesi maliyetsiz.
              'Range': 'bytes=0-32768',
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.6',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200 && response.statusCode != 206) {
        _cache[url] = null;
        return null;
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final image = _extractOg(body);
      _cache[url] = image;
      return image;
    } catch (_) {
      _cache[url] = null;
      return null;
    }
  }

  /// `<meta property="og:image" ...>` veya `<meta name="twitter:image" ...>`.
  /// Attribute sırası farklı olabiliyor (content önce gelebilir), bu yüzden
  /// hem `property=...content=...` hem de `content=...property=...` deniyoruz.
  String? _extractOg(String html) {
    // og:image öncelikli
    final patterns = [
      // property="og:image" ... content="..."
      RegExp(
        r'''<meta[^>]+(?:property|name)=["'](?:og:image(?::secure_url|:url)?|twitter:image(?::src)?)["'][^>]*content=["']([^"']+)["']''',
        caseSensitive: false,
      ),
      // content="..." ... property="og:image"
      RegExp(
        r'''<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["'](?:og:image(?::secure_url|:url)?|twitter:image(?::src)?)["']''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final m = pattern.firstMatch(html);
      if (m != null) {
        final raw = m.group(1)?.trim();
        if (raw != null && raw.isNotEmpty) {
          return _absolutize(raw, html);
        }
      }
    }
    return null;
  }

  /// `og:image` bazen `/uploads/x.jpg` gibi göreli geliyor — base URL'i
  /// HTML'in `<base href="">` veya canonical link'inden çıkar.
  String _absolutize(String url, String html) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    final canonical = RegExp(
      r'''<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (canonical != null) {
      final base = Uri.tryParse(canonical.group(1) ?? '');
      if (base != null) return base.resolve(url).toString();
    }
    return url;
  }

  /// Test/teardown için.
  static void clearCacheForTesting() {
    _cache.clear();
    _inflight.clear();
  }
}
