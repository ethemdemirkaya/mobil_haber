import 'package:flutter/material.dart';

/// Bir haber sağlayıcısı (gazete/ajans/site).
///
/// `mobil_haber` doğrudan istemci tarafında bu kaynakların RSS
/// feed'lerine bağlanır — backend bağımlılığı yoktur. Her sağlayıcı için:
///   - tek bir "ana" feed (kategori = `all`) ve
///   - kategori bazlı feed listesi
/// tanımlanır. Kategori bazlı feed yoksa NewsProvider o kategori için
/// "ana" feedi çekip içinde geçen ilgili kelimeleri filtreler.
class NewsSource {
  const NewsSource({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tagline,
    required this.domain,
    required this.brandColor,
    required this.primaryFeed,
    this.categoryFeeds = const {},
    this.recommended = false,
    this.country = 'TR',
    this.language = 'tr',
    this.kind = SourceKind.rss,
  });

  /// Sağlayıcı id (slug). SharedPreferences ve URL parametreleri.
  final String id;

  /// Tam ad (ör. "Anadolu Ajansı").
  final String name;

  /// Kısa ad (ör. "AA"). Liste/chip görünümü.
  final String shortName;

  /// Kısa açıklama (onboarding kart altyazısı).
  final String tagline;

  /// Ana domain — favicon ve atribüsyon için.
  final String domain;

  /// Marka rengi (chip/avatar arkaplanı için kullanılır).
  final Color brandColor;

  /// Tüm kategorileri dolduran genel feed URL'i.
  final String primaryFeed;

  /// Kategori-bazlı feed URL haritası. Anahtar `NewsCategory.id` slug'ı.
  /// Eksik kategoriler için `primaryFeed` kullanılır.
  final Map<String, String> categoryFeeds;

  /// Onboarding'de varsayılan olarak işaretli gelsin.
  final bool recommended;

  /// ISO ülke kodu.
  final String country;

  /// ISO dil kodu.
  final String language;

  /// RSS / Atom / JSON ayrımı. `mobil_haber`'in mevcut sürümü hepsini
  /// `RssNewsService` üzerinden okuyor ama bu alan ileride GDELT/HN gibi
  /// JSON kaynaklarını destekleyebilmek için ayrık tutuluyor.
  final SourceKind kind;

  /// Google'ın favicon servisi — her aktif domain için 128px PNG döndürür.
  /// Bu URL `cached_network_image` ile yüklenir, başarısız olursa
  /// widget tarafında brand-colored harf rozeti gösterilir.
  String get logoUrl =>
      'https://www.google.com/s2/favicons?domain=$domain&sz=128';

  /// Görsel kart arkasında gradient hissi için biraz daha açık bir varyant.
  Color get brandColorSoft => brandColor.withValues(alpha: 0.16);
}

enum SourceKind { rss, atom, json }

/// Sağlayıcı kataloğu — projenin "kaynak veritabanı" buradadır.
///
/// Yeni bir sağlayıcı eklemek için sadece bu listeye bir `NewsSource`
/// kaydı eklemek yeterlidir; UI ve aggregator otomatik olarak ona göre
/// çalışır.
class NewsSourceCatalog {
  NewsSourceCatalog._();

  /// Türk basını öne çıkanlar — RSS feed'leri Mayıs 2026 itibariyle
  /// `api-search.md` raporundaki referanslarla doğrulanmıştır.
  static const List<NewsSource> all = [
    // ───── Ulusal ajanslar ─────
    NewsSource(
      id: 'aa',
      name: 'Anadolu Ajansı',
      shortName: 'AA',
      tagline: 'Türkiye\'nin haber ajansı — 1920\'den beri',
      domain: 'aa.com.tr',
      brandColor: Color(0xFF002B5C),
      primaryFeed: 'https://www.aa.com.tr/tr/rss/default?cat=guncel',
      categoryFeeds: {
        'gundem': 'https://www.aa.com.tr/tr/rss/default?cat=guncel',
        'politika': 'https://www.aa.com.tr/tr/rss/default?cat=politika',
        'ekonomi': 'https://www.aa.com.tr/tr/rss/default?cat=ekonomi',
        'spor': 'https://www.aa.com.tr/tr/rss/default?cat=spor',
        'dunya': 'https://www.aa.com.tr/tr/rss/default?cat=dunya',
        'kultur': 'https://www.aa.com.tr/tr/rss/default?cat=kultur',
        'bilim': 'https://www.aa.com.tr/tr/rss/default?cat=bilim-teknoloji',
        'teknoloji':
            'https://www.aa.com.tr/tr/rss/default?cat=bilim-teknoloji',
        'saglik': 'https://www.aa.com.tr/tr/rss/default?cat=saglik',
        'egitim': 'https://www.aa.com.tr/tr/rss/default?cat=egitim',
      },
      recommended: true,
    ),

    // ───── Devlet kuruluşu ─────
    NewsSource(
      id: 'trthaber',
      name: 'TRT Haber',
      shortName: 'TRT Haber',
      tagline: 'Türkiye\'nin güvenilir haber kanalı',
      domain: 'trthaber.com',
      brandColor: Color(0xFFE30613),
      primaryFeed: 'https://www.trthaber.com/manset_articles.rss',
      categoryFeeds: {
        'gundem': 'https://www.trthaber.com/gundem_articles.rss',
        'spor': 'https://www.trthaber.com/spor_articles.rss',
        'ekonomi': 'https://www.trthaber.com/ekonomi_articles.rss',
        'dunya': 'https://www.trthaber.com/dunya_articles.rss',
        'teknoloji':
            'https://www.trthaber.com/bilim_teknoloji_articles.rss',
        'bilim': 'https://www.trthaber.com/bilim_teknoloji_articles.rss',
        'kultur': 'https://www.trthaber.com/kultur_sanat_articles.rss',
        'sanat': 'https://www.trthaber.com/kultur_sanat_articles.rss',
        'saglik': 'https://www.trthaber.com/saglik_articles.rss',
        'egitim': 'https://www.trthaber.com/egitim_articles.rss',
        'yasam': 'https://www.trthaber.com/yasam_articles.rss',
      },
      recommended: true,
    ),

    // ───── Büyük ulusal gazeteler ─────
    NewsSource(
      id: 'sabah',
      name: 'Sabah',
      shortName: 'Sabah',
      tagline: 'Geniş kategori yelpazesi, görsel zengin',
      domain: 'sabah.com.tr',
      brandColor: Color(0xFFCC0000),
      primaryFeed: 'https://www.sabah.com.tr/rss/news.xml',
      categoryFeeds: {
        'gundem': 'https://www.sabah.com.tr/rss/gundem.xml',
        'spor': 'https://www.sabah.com.tr/rss/spor.xml',
        'ekonomi': 'https://www.sabah.com.tr/rss/ekonomi.xml',
        'dunya': 'https://www.sabah.com.tr/rss/dunya.xml',
        'teknoloji': 'https://www.sabah.com.tr/rss/teknoloji.xml',
        'yasam': 'https://www.sabah.com.tr/rss/yasam.xml',
        'saglik': 'https://www.sabah.com.tr/rss/saglik.xml',
        'kultur': 'https://www.sabah.com.tr/rss/kultur-sanat.xml',
        'sanat': 'https://www.sabah.com.tr/rss/kultur-sanat.xml',
        'seyahat': 'https://www.sabah.com.tr/rss/turizm.xml',
      },
      recommended: true,
    ),

    NewsSource(
      id: 'sozcu',
      name: 'Sözcü',
      shortName: 'Sözcü',
      tagline: 'En geniş kategori listesi (34+ feed)',
      domain: 'sozcu.com.tr',
      brandColor: Color(0xFFE2231A),
      primaryFeed: 'https://www.sozcu.com.tr/feeds-haberler',
      categoryFeeds: {
        'gundem': 'https://www.sozcu.com.tr/feeds-rss-category-gundem',
        'dunya': 'https://www.sozcu.com.tr/feeds-rss-category-dunya',
        'ekonomi': 'https://www.sozcu.com.tr/feeds-rss-category-ekonomi',
        'spor': 'https://www.sozcu.com.tr/feeds-rss-category-spor',
        'teknoloji':
            'https://www.sozcu.com.tr/feeds-rss-category-bilim-teknoloji',
        'bilim':
            'https://www.sozcu.com.tr/feeds-rss-category-bilim-teknoloji',
        'yasam': 'https://www.sozcu.com.tr/feeds-rss-category-yasam',
        'saglik': 'https://www.sozcu.com.tr/feeds-rss-category-saglik',
        'kultur':
            'https://www.sozcu.com.tr/feeds-rss-category-kultur-sanat',
        'sanat':
            'https://www.sozcu.com.tr/feeds-rss-category-kultur-sanat',
        'egitim': 'https://www.sozcu.com.tr/feeds-rss-category-egitim',
      },
      recommended: true,
    ),

    NewsSource(
      id: 'hurriyet',
      name: 'Hürriyet',
      shortName: 'Hürriyet',
      tagline: 'Türkiye gazeteciliğinin köklü ismi',
      domain: 'hurriyet.com.tr',
      brandColor: Color(0xFFE30613),
      primaryFeed: 'http://www.hurriyet.com.tr/rss/anasayfa',
      categoryFeeds: {
        'gundem': 'http://www.hurriyet.com.tr/rss/gundem',
        'ekonomi': 'http://www.hurriyet.com.tr/rss/ekonomi',
        'spor': 'http://www.hurriyet.com.tr/rss/spor',
        'dunya': 'http://www.hurriyet.com.tr/rss/dunya',
      },
    ),

    NewsSource(
      id: 'milliyet',
      name: 'Milliyet',
      shortName: 'Milliyet',
      tagline: 'Son dakika ve gündem',
      domain: 'milliyet.com.tr',
      brandColor: Color(0xFFD7152C),
      primaryFeed: 'https://www.milliyet.com.tr/rss/rssNew/sondakika',
    ),

    NewsSource(
      id: 'cumhuriyet',
      name: 'Cumhuriyet',
      shortName: 'Cumhuriyet',
      tagline: 'Bağımsız haberciliğin sesi',
      domain: 'cumhuriyet.com.tr',
      brandColor: Color(0xFFC8102E),
      primaryFeed: 'https://www.cumhuriyet.com.tr/rss/son_dakika.xml',
    ),

    NewsSource(
      id: 'haberturk',
      name: 'Habertürk',
      shortName: 'Habertürk',
      tagline: 'Genel haber portalı',
      domain: 'haberturk.com',
      brandColor: Color(0xFF003D7A),
      primaryFeed: 'https://www.haberturk.com/rss',
      categoryFeeds: {
        'ekonomi': 'https://www.haberturk.com/rss/ekonomi.xml',
        'spor': 'https://www.haberturk.com/rss/spor.xml',
      },
    ),

    NewsSource(
      id: 'cnnturk',
      name: 'CNN Türk',
      shortName: 'CNN Türk',
      tagline: 'Türkiye\'den ve dünyadan haberler',
      domain: 'cnnturk.com',
      brandColor: Color(0xFFCC0000),
      primaryFeed: 'https://www.cnnturk.com/feed/rss/all/news',
      categoryFeeds: {
        'gundem': 'https://www.cnnturk.com/feed/rss/turkiye/news',
        'dunya': 'https://www.cnnturk.com/feed/rss/dunya/news',
        'ekonomi': 'https://www.cnnturk.com/feed/rss/ekonomi/news',
        'spor': 'https://www.cnnturk.com/feed/rss/spor/news',
        'teknoloji': 'https://www.cnnturk.com/feed/rss/teknoloji/news',
        'saglik': 'https://www.cnnturk.com/feed/rss/saglik/news',
      },
    ),

    NewsSource(
      id: 'ntv',
      name: 'NTV',
      shortName: 'NTV',
      tagline: 'Hızlı son dakika gelişmeleri',
      domain: 'ntv.com.tr',
      brandColor: Color(0xFF005FAA),
      primaryFeed: 'https://www.ntv.com.tr/gundem.rss',
      categoryFeeds: {
        'gundem': 'https://www.ntv.com.tr/gundem.rss',
        'ekonomi': 'https://www.ntv.com.tr/ekonomi.rss',
        'dunya': 'https://www.ntv.com.tr/dunya.rss',
        'teknoloji': 'https://www.ntv.com.tr/teknoloji.rss',
        'saglik': 'https://www.ntv.com.tr/saglik.rss',
      },
      recommended: true,
    ),

    NewsSource(
      id: 'yenisafak',
      name: 'Yeni Şafak',
      shortName: 'Yeni Şafak',
      tagline: 'Genel haber, analiz',
      domain: 'yenisafak.com',
      brandColor: Color(0xFF003E7E),
      primaryFeed: 'https://www.yenisafak.com/rss-feeds?take=60',
      categoryFeeds: {
        'gundem': 'https://www.yenisafak.com/rss-feeds?category=gundem',
        'dunya': 'https://www.yenisafak.com/rss-feeds?category=dunya',
        'ekonomi': 'https://www.yenisafak.com/rss-feeds?category=ekonomi',
        'spor': 'https://www.yenisafak.com/rss-feeds?category=spor',
        'teknoloji':
            'https://www.yenisafak.com/rss-feeds?category=teknoloji',
        'yasam': 'https://www.yenisafak.com/rss-feeds?category=hayat',
      },
    ),

    // ───── Bağımsız / alternatif ─────
    NewsSource(
      id: 'diken',
      name: 'Diken',
      shortName: 'Diken',
      tagline: 'Bağımsız haber sitesi',
      domain: 'diken.com.tr',
      brandColor: Color(0xFF1A1A1A),
      primaryFeed: 'https://www.diken.com.tr/feed/',
    ),

    // ───── Uluslararası (Türkçe) ─────
    NewsSource(
      id: 'bbcturkce',
      name: 'BBC Türkçe',
      shortName: 'BBC Türkçe',
      tagline: 'Dünya gözüyle Türkiye ve dünya',
      domain: 'bbc.com',
      brandColor: Color(0xFFB80000),
      primaryFeed: 'https://feeds.bbci.co.uk/turkce/rss.xml',
      country: 'GB',
      recommended: true,
    ),
  ];

  static NewsSource? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Onboarding ilk açılışta varsayılan olarak seçilen kaynaklar.
  static List<String> get recommendedIds =>
      all.where((s) => s.recommended).map((s) => s.id).toList();
}
