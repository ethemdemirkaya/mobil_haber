import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/news_source.dart';

/// Doğrudan istemci tarafında çalışan RSS aggregator.
///
/// Backend gerektirmez. Verilen `NewsSource` listesi için her bir feed'i
/// paralel çeker, RSS 2.0 / Atom çıktısını `Article` listesine
/// normalize eder ve birleştirip yayın tarihine göre sıralar.
///
/// Ağ stratejisi:
///   - Feed başına 8 sn timeout — kötü kaynaklar tüm ana akışı bekletmesin.
///   - Tarayıcı tabanlı User-Agent gönderiyor; bazı CDN'ler default Dart
///     UA'ya 403 verebiliyor.
///   - Hatalı/erişilemeyen kaynaklar sessizce atlanır, başarılılar listeye
///     eklenir.
class RssNewsService {
  RssNewsService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const Duration _feedTimeout = Duration(seconds: 8);
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; mobil_haber) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  /// Birden çok kaynaktan paralel olarak haberleri toplar.
  ///
  /// [category] verilirse her kaynak için kategoriye özel feed denenir
  /// (yoksa primary feed'e düşülür). [perSource] her kaynaktan en fazla
  /// kaç haber alınacağını belirler.
  Future<List<Article>> aggregate(
    List<NewsSource> sources, {
    String? category,
    int perSource = 8,
  }) async {
    if (sources.isEmpty) return const [];
    final results = await Future.wait(
      sources.map((s) => _fetchSourceSafe(s,
          category: category, limit: perSource)),
      eagerError: false,
    );
    final all = <Article>[];
    for (final list in results) {
      all.addAll(list);
    }
    all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return all;
  }

  /// Tek bir kaynak için makaleleri çeker (UI'da "tek kaynak" görünümü).
  Future<List<Article>> fetchOne(
    NewsSource source, {
    String? category,
    int limit = 30,
  }) =>
      _fetchSourceSafe(source, category: category, limit: limit);

  Future<List<Article>> _fetchSourceSafe(
    NewsSource source, {
    String? category,
    required int limit,
  }) async {
    try {
      final url = _resolveFeedUrl(source, category);
      final body = await _fetch(url);
      final articles = _parseRss(body, source: source, fallback: category);
      if (articles.length <= limit) return articles;
      return articles.sublist(0, limit);
    } catch (_) {
      // Bir kaynak başarısız olduğunda akışı bozma; sessizce atla.
      return const [];
    }
  }

  String _resolveFeedUrl(NewsSource source, String? category) {
    if (category != null && category.isNotEmpty) {
      final mapped = source.categoryFeeds[category];
      if (mapped != null) return mapped;
    }
    return source.primaryFeed;
  }

  Future<String> _fetch(String url) async {
    final response = await _client
        .get(
          Uri.parse(url),
          headers: const {
            'User-Agent': _userAgent,
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
            // Bazı CDN'ler dil tabanlı içerik dönmüyor ama göndermesi
            // güvenli — Türkçe öncelikli rss servet eden sunucular için.
            'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.6',
          },
        )
        .timeout(_feedTimeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    // Pek çok TR RSS feedi (Habertürk, NTV, T24 vb.) `Content-Type`
    // header'ında charset bildirmiyor ya da yanlış formatta veriyor
    // (`text/xml; charset:utf-8;;charset=UTF-8` gibi). `http` paketinin
    // `response.body` getter'ı charset yoksa **latin-1** ile decode eder
    // — sonuç: UTF-8 byte'ları "Ã„Â±" / mojibake olur.
    //
    // Çözüm: ham byte'lardan zorla UTF-8 dene; başarısız olursa latin-1
    // (gerçekten 8859 olan eski bir kaynak gelirse).
    final bytes = response.bodyBytes;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  List<Article> _parseRss(
    String xml, {
    required NewsSource source,
    String? fallback,
  }) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      return const [];
    }

    // RSS 2.0
    final items = doc.findAllElements('item').toList();
    if (items.isNotEmpty) {
      return items
          .map((e) => _itemToArticle(e, source: source, fallback: fallback))
          .whereType<Article>()
          .toList(growable: false);
    }

    // Atom
    final entries = doc.findAllElements('entry').toList();
    if (entries.isNotEmpty) {
      return entries
          .map((e) => _entryToArticle(e, source: source, fallback: fallback))
          .whereType<Article>()
          .toList(growable: false);
    }

    return const [];
  }

  Article? _itemToArticle(
    XmlElement el, {
    required NewsSource source,
    String? fallback,
  }) {
    final title = _firstText(el, ['title']);
    final link = _firstText(el, ['link', 'guid']);
    if (title.isEmpty || link.isEmpty) return null;

    final descRaw = _firstText(el, ['description', 'summary']);
    final contentRaw =
        _firstNamespacedText(el, ['encoded', 'content']) ??
            _firstText(el, ['content']);
    final pubDate = _parseDate(_firstText(el, ['pubDate', 'date']));

    final image = _extractImage(el, fallbackHtml: descRaw);
    final author = _firstText(el, ['author', 'creator']);
    final categoryId = _resolveCategory(
      explicit: fallback,
      title: title,
      summary: descRaw,
      categoryNodes: el.findElements('category'),
      sourceUrl: link,
    );

    final summary = _stripHtml(descRaw);
    final content = _stripHtml(contentRaw);

    return Article(
      id: _stableId(link),
      title: _decodeEntities(title.trim()),
      summary: _decodeEntities(_truncate(summary, 320)),
      content: _decodeEntities(content.isEmpty ? summary : content),
      categoryId: categoryId,
      imageUrl: image,
      author: author.isEmpty ? source.name : author,
      publishedAt: pubDate ?? DateTime.now(),
      readMinutes: _estimateReadMinutes(content.isEmpty ? summary : content),
      isFeatured: false,
      sourceUrl: link.trim(),
      sourceName: source.name,
    );
  }

  Article? _entryToArticle(
    XmlElement el, {
    required NewsSource source,
    String? fallback,
  }) {
    final title = _firstText(el, ['title']);
    String link = '';
    for (final l in el.findElements('link')) {
      final href = l.getAttribute('href');
      if (href != null && href.isNotEmpty) {
        link = href;
        break;
      }
    }
    if (link.isEmpty) link = _firstText(el, ['id']);
    if (title.isEmpty || link.isEmpty) return null;

    final summaryRaw = _firstText(el, ['summary', 'content']);
    final pubDate = _parseDate(
      _firstText(el, ['updated', 'published', 'date']),
    );
    final image = _extractImage(el, fallbackHtml: summaryRaw);
    final author = _firstText(
      el.findElements('author').isEmpty ? el : el.findElements('author').first,
      ['name'],
    );
    final categoryId = _resolveCategory(
      explicit: fallback,
      title: title,
      summary: summaryRaw,
      categoryNodes: el.findElements('category'),
      sourceUrl: link,
    );
    final summary = _stripHtml(summaryRaw);

    return Article(
      id: _stableId(link),
      title: _decodeEntities(title.trim()),
      summary: _decodeEntities(_truncate(summary, 320)),
      content: _decodeEntities(summary),
      categoryId: categoryId,
      imageUrl: image,
      author: author.isEmpty ? source.name : author,
      publishedAt: pubDate ?? DateTime.now(),
      readMinutes: _estimateReadMinutes(summary),
      isFeatured: false,
      sourceUrl: link.trim(),
      sourceName: source.name,
    );
  }

  // ─────────── Yardımcılar ───────────

  String _firstText(XmlElement el, List<String> tags) {
    for (final t in tags) {
      final node = el.findElements(t).firstOrNull;
      if (node != null) {
        final v = node.innerText.trim();
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  String? _firstNamespacedText(XmlElement el, List<String> localNames) {
    for (final node in el.descendants.whereType<XmlElement>()) {
      if (localNames.contains(node.localName)) {
        final v = node.innerText.trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  /// Görseli sırasıyla `media:thumbnail`, `media:content`, `enclosure`,
  /// `image`, ve içerik HTML'inden ilk `<img src="...">` üzerinden çıkarır.
  String _extractImage(XmlElement el, {String fallbackHtml = ''}) {
    for (final node in el.descendants.whereType<XmlElement>()) {
      if (node.localName == 'thumbnail' || node.localName == 'content') {
        final url = node.getAttribute('url');
        if (url != null && _looksLikeImage(url)) return url;
      }
      if (node.localName == 'enclosure') {
        final url = node.getAttribute('url');
        final type = node.getAttribute('type') ?? '';
        if (url != null && (type.startsWith('image/') || _looksLikeImage(url))) {
          return url;
        }
      }
      if (node.localName == 'image') {
        final url = node.getAttribute('url') ?? node.innerText.trim();
        if (url.isNotEmpty && _looksLikeImage(url)) return url;
      }
    }
    if (fallbackHtml.isNotEmpty) {
      final m = RegExp(
        r'''<img[^>]+src=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(fallbackHtml);
      if (m != null) return m.group(1) ?? '';
    }
    return '';
  }

  bool _looksLikeImage(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.png') ||
        u.endsWith('.webp') ||
        u.endsWith('.gif') ||
        u.contains('image/') ||
        u.contains('img/') ||
        u.contains('photo');
  }

  /// Kategori belirleme:
  ///   1) Çağıran (NewsProvider) bir kategori dayatmışsa onu kullan.
  ///   2) RSS `<category>` etiketleri varsa Türkçe slug'a eşle.
  ///   3) Başlık/özet/URL içinde anahtar kelime taraması.
  ///   4) Hiçbiri tutmazsa "gundem".
  String _resolveCategory({
    String? explicit,
    required String title,
    required String summary,
    required Iterable<XmlElement> categoryNodes,
    required String sourceUrl,
  }) {
    if (explicit != null && explicit.isNotEmpty && explicit != 'all') {
      return explicit;
    }
    for (final c in categoryNodes) {
      final mapped = _mapCategoryName(c.innerText.trim());
      if (mapped != null) return mapped;
    }
    final blob =
        '${title.toLowerCase()} ${summary.toLowerCase()} ${sourceUrl.toLowerCase()}';
    for (final entry in _keywordMap.entries) {
      for (final kw in entry.value) {
        if (blob.contains(kw)) return entry.key;
      }
    }
    return NewsCategory.all.id == 'all' ? 'gundem' : NewsCategory.all.id;
  }

  static const Map<String, List<String>> _keywordMap = {
    'spor': [' spor', '/spor', 'futbol', 'basketbol', 'maç ', 'galatasaray',
        'fenerbahçe', 'beşiktaş', 'olimpi', 'voleybol'],
    'ekonomi': ['ekonomi', '/ekonomi', 'borsa', 'döviz', 'enflasyon',
        'merkez bankası', 'piyasa', 'kripto', 'altın'],
    'teknoloji': ['/teknoloji', 'teknoloji', 'yapay zek', ' iphone', 'samsung',
        'android', 'yazılım', 'donanım'],
    'bilim': ['bilim', '/bilim', 'araştırma', 'uzay', 'nasa'],
    'saglik': ['sağlık', '/saglik', 'sağlık', 'hastane', 'aşı', 'doktor',
        'tıp '],
    'dunya': ['/dunya', 'dünya', 'avrupa', 'amerika', 'asya', 'putin',
        'biden', 'trump', 'gazze', 'ukrayna'],
    'kultur': ['/kultur', 'kültür', 'sergi', 'müzik', 'sinema'],
    'sanat': ['sanat', '/sanat', 'tiyatro', 'opera'],
    'egitim': ['eğitim', '/egitim', 'okul', 'üniversite', 'meb '],
    'yasam': ['yaşam', '/yasam', 'magazin', '/magazin'],
    'seyahat': ['seyahat', '/seyahat', 'turizm', '/turizm', 'tatil'],
    'gundem': [' gündem', '/gundem', 'son dakika', 'cumhurbaşkan'],
  };

  String? _mapCategoryName(String name) {
    final n = name
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ğ', 'g')
        .trim();
    if (n.isEmpty) return null;
    if (n.contains('gundem') || n.contains('turkiye')) return 'gundem';
    if (n.contains('spor')) return 'spor';
    if (n.contains('ekonomi') || n.contains('finans') || n.contains('borsa')) {
      return 'ekonomi';
    }
    if (n.contains('teknoloji')) return 'teknoloji';
    if (n.contains('bilim')) return 'bilim';
    if (n.contains('saglik')) return 'saglik';
    if (n.contains('dunya')) return 'dunya';
    if (n.contains('kultur')) return 'kultur';
    if (n.contains('sanat')) return 'sanat';
    if (n.contains('egitim')) return 'egitim';
    if (n.contains('yasam') || n.contains('magazin') || n.contains('hayat')) {
      return 'yasam';
    }
    if (n.contains('turizm') || n.contains('seyahat')) return 'seyahat';
    return null;
  }

  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    // <br> / <p> kapanışlarında yumuşak boşluk bırakıp tag'leri sök.
    final clean = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return clean.trim();
  }

  String _decodeEntities(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) {
            final code = int.tryParse(m.group(1) ?? '');
            return code == null ? m.group(0)! : String.fromCharCode(code);
          },
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) {
            final code = int.tryParse(m.group(1) ?? '', radix: 16);
            return code == null ? m.group(0)! : String.fromCharCode(code);
          },
        );
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max).trim()}…';
  }

  int _estimateReadMinutes(String text) {
    if (text.isEmpty) return 1;
    final words = text.split(RegExp(r'\s+')).length;
    // Türkçe ortalama 200 wpm okuma; özet için minimum 1 dk.
    return (words / 200).ceil().clamp(1, 30);
  }

  String _stableId(String url) {
    // sha1 yerine deterministik küçük hash — id eşleşsin diye yeterli.
    final bytes = utf8.encode(url);
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h = (h ^ b) & 0xffffffff;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return 'rss_${h.toRadixString(16).padLeft(8, '0')}';
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    // ISO 8601
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    // RFC 822 (RSS) — "Thu, 07 May 2026 18:50:00 +0300"
    return _parseRfc822(s);
  }

  DateTime? _parseRfc822(String s) {
    final parts = s.split(' ');
    if (parts.length < 5) return null;
    try {
      // 0:Day-of-week,? 1:day 2:Mon 3:year 4:HH:MM[:SS] 5:tz
      var idx = 0;
      if (parts[0].endsWith(',')) idx = 1;
      final day = int.parse(parts[idx]);
      final month = _months[parts[idx + 1].toLowerCase()];
      if (month == null) return null;
      final year = int.parse(parts[idx + 2]);
      final timeBits = parts[idx + 3].split(':');
      final hour = int.parse(timeBits[0]);
      final minute = int.parse(timeBits[1]);
      final second = timeBits.length > 2 ? int.parse(timeBits[2]) : 0;
      // Saat dilimi farkını UTC'ye çevir; basit -> direkt UTC kabul ediyoruz.
      final utc = DateTime.utc(year, month, day, hour, minute, second);
      if (parts.length > idx + 4) {
        final tz = parts[idx + 4];
        final m = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(tz);
        if (m != null) {
          final sign = m.group(1) == '+' ? 1 : -1;
          final hh = int.parse(m.group(2)!);
          final mm = int.parse(m.group(3)!);
          return utc.subtract(
            Duration(hours: sign * hh, minutes: sign * mm),
          );
        }
      }
      return utc;
    } catch (_) {
      return null;
    }
  }

  static const Map<String, int> _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  void close() => _client.close();
}
