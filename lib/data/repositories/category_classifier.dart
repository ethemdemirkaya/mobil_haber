import '../../core/utils/turkish_text.dart';

/// RSS öğelerine kategori atayan kural tabanlı sınıflandırıcı.
///
/// Öncelik sırası (yüksek kesinlikten düşüğe):
///   1. Çağıranın dayattığı kategori (kategoriye özel feed).
///   2. RSS `<category>` etiketleri.
///   3. URL yol segmentleri (`/spor/`, `/ekonomi/` …).
///   4. Anahtar kelime puanlaması — başlıktaki eşleşme 2, özetteki 1 puan;
///      en az [_minScore] puan alan en yüksek kategori seçilir.
///   5. Hiçbiri tutmazsa `gundem`.
///
/// Eşleşme alt-dize (`contains`) ile değil, kelime + Türkçe ek zinciri ile
/// yapılır: "yaşındaki" artık "aşı" (sağlık), "operasyon" artık "opera"
/// (sanat) sayılmaz.
class CategoryClassifier {
  const CategoryClassifier();

  static const String fallback = 'gundem';
  static const int _minScore = 2;

  String classify({
    String? explicit,
    required String title,
    required String summary,
    Iterable<String> rssCategories = const [],
    String url = '',
  }) {
    if (explicit != null && explicit.isNotEmpty && explicit != 'all') {
      return explicit;
    }
    for (final c in rssCategories) {
      final mapped = mapLabel(c);
      if (mapped != null) return mapped;
    }
    final fromUrl = _fromUrl(url);
    if (fromUrl != null) return fromUrl;

    final titleTokens = trTokens(title);
    final summaryTokens = trTokens(summary);
    String? best;
    var bestScore = 0;
    for (final entry in _keywords.entries) {
      var score = 0;
      for (final kw in entry.value) {
        if (_containsKeyword(titleTokens, kw)) score += 2;
        if (_containsKeyword(summaryTokens, kw)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    if (best != null && bestScore >= _minScore) return best;
    return fallback;
  }

  /// Serbest bir kategori etiketini (RSS `<category>`, URL segmenti)
  /// uygulama kategori id'sine eşler.
  String? mapLabel(String label) {
    final n = foldTr(label).trim();
    if (n.isEmpty) return null;
    if (n.contains('gundem') || n.contains('turkiye') || n == 'politika') {
      return 'gundem';
    }
    if (n.contains('spor') || n.contains('futbol')) return 'spor';
    if (n.contains('ekonomi') || n.contains('finans') || n.contains('borsa')) {
      return 'ekonomi';
    }
    if (n.contains('teknoloji') || n == 'tekno') return 'teknoloji';
    if (n.contains('bilim')) return 'bilim';
    if (n.contains('saglik')) return 'saglik';
    if (n.contains('dunya') || n == 'world') return 'dunya';
    if (n.contains('kultur')) return 'kultur';
    if (n.contains('sanat')) return 'sanat';
    if (n.contains('egitim')) return 'egitim';
    if (n.contains('yasam') || n.contains('magazin') || n.contains('hayat')) {
      return 'yasam';
    }
    if (n.contains('turizm') || n.contains('seyahat')) return 'seyahat';
    return null;
  }

  /// Sadece kısa, tire içermeyen segmentlere bakar — "dunya-kupasi-…" gibi
  /// slug'lar başlık kelimeleri taşıdığı için kategori sinyali değildir.
  String? _fromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    for (final seg in uri.pathSegments) {
      if (seg.isEmpty || seg.contains('-') || seg.length > 16) continue;
      final mapped = mapLabel(seg);
      if (mapped != null) return mapped;
    }
    return null;
  }

  /// [kw] tek kelime ya da boşlukla ayrılmış kelime öbeği olabilir. Öbekte
  /// her kelime ardışık token'larla (ekli hâlleri dahil) eşleşmelidir.
  static bool _containsKeyword(List<String> tokens, String kw) {
    final parts = kw.split(' ');
    if (parts.length == 1) {
      for (final t in tokens) {
        if (stemMatches(t, kw)) return true;
      }
      return false;
    }
    for (var i = 0; i + parts.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < parts.length; j++) {
        if (!stemMatches(tokens[i + j], parts[j])) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// Kökler [trLower] biçiminde yazılır. Belirsiz kelimeler bilinçli olarak
  /// yok: "altın" ("altında"), "hastane" (kaza haberleri), "dünya"
  /// ("Dünya Kupası") gibi.
  static const Map<String, List<String>> _keywords = {
    'spor': [
      'spor', 'futbol', 'basketbol', 'voleybol', 'maç', 'lig', 'süper lig',
      'galatasaray', 'fenerbahçe', 'beşiktaş', 'trabzonspor', 'olimpiyat',
      'teknik direktör', 'transfer', 'şampiyonlar ligi', 'milli takım',
      'gol', 'derbi',
    ],
    'ekonomi': [
      'ekonomi', 'borsa', 'döviz', 'dolar', 'euro', 'enflasyon',
      'merkez bankası', 'faiz', 'piyasa', 'kripto', 'bitcoin',
      'gram altın', 'altın fiyat', 'ons altın', 'çeyrek altın', 'ihracat',
      'ithalat', 'büyüme rakam', 'asgari ücret', 'bist',
    ],
    'teknoloji': [
      'teknoloji', 'yapay zeka', 'iphone', 'samsung', 'android', 'yazılım',
      'donanım', 'apple', 'google', 'openai', 'akıllı telefon', 'siber',
    ],
    'bilim': [
      'bilim', 'bilim insan', 'uzay', 'nasa', 'gezegen', 'fosil',
      'keşif',
    ],
    'saglik': [
      'sağlık', 'aşı', 'tıp', 'kanser', 'virüs', 'salgın', 'grip',
      'tedavi', 'hastalık', 'sağlık bakan',
    ],
    'dunya': [
      'avrupa birliği', 'nato', 'birleşmiş milletler', 'beyaz saray',
      'kremlin', 'putin', 'trump', 'gazze', 'ukrayna', 'israil', 'iran',
      'rusya', 'abd', 'çin',
    ],
    'kultur': ['kültür', 'sergi', 'müzik', 'sinema', 'kitap', 'festival'],
    'sanat': ['sanat', 'tiyatro', 'opera', 'bale', 'ressam', 'konser'],
    'egitim': [
      'eğitim', 'okul', 'üniversite', 'meb', 'öğrenci', 'öğretmen',
      'lgs', 'yks',
    ],
    'yasam': ['yaşam', 'magazin', 'ünlü', 'moda'],
    'seyahat': ['seyahat', 'turizm', 'tatil', 'otel', 'turist'],
    'gundem': [
      'son dakika', 'cumhurbaşkan', 'meclis', 'tbmm', 'bakan', 'seçim',
      'valilik', 'emniyet',
    ],
  };
}
