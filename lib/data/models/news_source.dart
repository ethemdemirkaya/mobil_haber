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
      primaryFeed: 'https://www.hurriyet.com.tr/rss/anasayfa',
      categoryFeeds: {
        'gundem': 'https://www.hurriyet.com.tr/rss/gundem',
        'ekonomi': 'https://www.hurriyet.com.tr/rss/ekonomi',
        'spor': 'https://www.hurriyet.com.tr/rss/spor',
        'dunya': 'https://www.hurriyet.com.tr/rss/dunya',
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

    // ───── Uluslararası (Türkçe yayın) ─────
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

    NewsSource(
      id: 'dwturkce',
      name: 'DW Türkçe',
      shortName: 'DW Türkçe',
      tagline: 'Deutsche Welle — Avrupa odaklı analiz',
      domain: 'dw.com',
      brandColor: Color(0xFF003E8E),
      primaryFeed: 'https://rss.dw.com/rdf/rss-tur-all',
      country: 'DE',
    ),

    NewsSource(
      id: 'euronews',
      name: 'Euronews Türkçe',
      shortName: 'Euronews',
      tagline: 'Avrupa\'dan ve dünyadan haberler',
      domain: 'euronews.com',
      brandColor: Color(0xFF005CFF),
      primaryFeed: 'https://tr.euronews.com/rss',
      country: 'FR',
    ),

    NewsSource(
      id: 'indyturkce',
      name: 'Independent Türkçe',
      shortName: 'Indy Türkçe',
      tagline: 'Bağımsız uluslararası perspektif',
      domain: 'indyturk.com',
      brandColor: Color(0xFFEF3340),
      primaryFeed: 'https://www.indyturk.com/rss.xml',
      country: 'GB',
    ),

    // ───── Bağımsız Türk medyası ─────
    NewsSource(
      id: 'gazeteduvar',
      name: 'Gazete Duvar',
      shortName: 'Duvar',
      tagline: 'Bağımsız haber ve yorum',
      domain: 'gazeteduvar.com.tr',
      brandColor: Color(0xFF111111),
      primaryFeed: 'https://www.gazeteduvar.com.tr/rss',
    ),

    NewsSource(
      id: 'artigercek',
      name: 'Artı Gerçek',
      shortName: 'Artı Gerçek',
      tagline: 'Bağımsız haber ve analiz',
      domain: 'artigercek.com',
      brandColor: Color(0xFFFE0000),
      primaryFeed: 'https://artigercek.com/export/rss',
    ),

    NewsSource(
      id: 'karar',
      name: 'Karar',
      shortName: 'Karar',
      tagline: 'Geniş yelpazede yorum ve haber',
      domain: 'karar.com',
      brandColor: Color(0xFF0E5DAA),
      primaryFeed: 'https://www.karar.com/rss',
      // Karar'ın `?cat=...` parametresi anasayfa feed'ine dönüyor;
      // gerçek kategori filtrelemesi yok. Tek feed yeterli.
    ),

    NewsSource(
      id: 'halktv',
      name: 'Halk TV',
      shortName: 'Halk TV',
      tagline: 'Muhalefete yakın haber kanalı ve yorumlar',
      domain: 'halktv.com.tr',
      brandColor: Color(0xFFCC0033),
      primaryFeed: 'https://halktv.com.tr/service/rss.php',
    ),

    NewsSource(
      id: 'tele1',
      name: 'TELE1',
      shortName: 'TELE1',
      tagline: 'Bağımsız haber kanalı — politika ağırlıklı',
      domain: 'tele1.com.tr',
      brandColor: Color(0xFF1976D2),
      primaryFeed: 'https://www.tele1.com.tr/rss',
    ),

    NewsSource(
      id: 'odatv',
      name: 'OdaTV',
      shortName: 'OdaTV',
      tagline: 'Bağımsız internet gazetesi',
      domain: 'odatv4.com',
      brandColor: Color(0xFFC8232A),
      primaryFeed: 'https://www.odatv4.com/rss.xml',
    ),

    NewsSource(
      id: 'aydinlik',
      name: 'Aydınlık',
      shortName: 'Aydınlık',
      tagline: 'Ulusalcı çizgide günlük gazete',
      domain: 'aydinlik.com.tr',
      brandColor: Color(0xFFD32F2F),
      primaryFeed: 'https://www.aydinlik.com.tr/rss',
    ),

    NewsSource(
      id: 'yenicag',
      name: 'Yeniçağ',
      shortName: 'Yeniçağ',
      tagline: 'Milliyetçi/muhalif çizgide gazete',
      domain: 'yenicaggazetesi.com.tr',
      brandColor: Color(0xFF00528E),
      primaryFeed: 'https://www.yenicaggazetesi.com.tr/rss',
    ),

    NewsSource(
      id: 'veryansintv',
      name: 'Veryansın TV',
      shortName: 'Veryansın',
      tagline: 'Bağımsız haber — siyaset ve dış politika',
      domain: 'veryansintv.com',
      brandColor: Color(0xFFB71C1C),
      primaryFeed: 'https://www.veryansintv.com/feed/',
    ),

    NewsSource(
      id: 'medyascope',
      name: 'Medyascope',
      shortName: 'Medyascope',
      tagline: 'Bağımsız internet TV ve podcast haberciliği',
      domain: 'medyascope.tv',
      brandColor: Color(0xFF00897B),
      primaryFeed: 'https://medyascope.tv/feed/',
    ),

    NewsSource(
      id: 'gercekgundem',
      name: 'Gerçek Gündem',
      shortName: 'Gerçek Gündem',
      tagline: 'Bağımsız haber portalı',
      domain: 'gercekgundem.com',
      brandColor: Color(0xFF0066CC),
      primaryFeed: 'https://www.gercekgundem.com/feed/',
    ),

    // ───── Ek ulusal gazeteler ─────
    NewsSource(
      id: 'vatan',
      name: 'Vatan',
      shortName: 'Vatan',
      tagline: 'Demirören grubu ulusal gazete',
      domain: 'gazetevatan.com',
      brandColor: Color(0xFFFF3300),
      primaryFeed: 'https://www.gazetevatan.com/rss/sondakika.xml',
      categoryFeeds: {
        'gundem': 'https://www.gazetevatan.com/rss/gundem.xml',
        'ekonomi': 'https://www.gazetevatan.com/rss/ekonomi.xml',
        'spor': 'https://www.gazetevatan.com/rss/spor.xml',
        'dunya': 'https://www.gazetevatan.com/rss/dunya.xml',
      },
    ),

    NewsSource(
      id: 'turkiyegazetesi',
      name: 'Türkiye Gazetesi',
      shortName: 'Türkiye',
      tagline: 'Muhafazakar günlük gazete',
      domain: 'turkiyegazetesi.com.tr',
      brandColor: Color(0xFF003366),
      primaryFeed: 'https://www.turkiyegazetesi.com.tr/rss',
      categoryFeeds: {
        'gundem': 'https://www.turkiyegazetesi.com.tr/rss/gundem',
        'ekonomi': 'https://www.turkiyegazetesi.com.tr/rss/ekonomi',
        'spor': 'https://www.turkiyegazetesi.com.tr/rss/spor',
      },
    ),

    // ───── Genel internet portalları ─────
    NewsSource(
      id: 'internethaber',
      name: 'İnternethaber',
      shortName: 'İnternethaber',
      tagline: 'Geniş yelpazeli haber portalı',
      domain: 'internethaber.com',
      brandColor: Color(0xFFC62828),
      primaryFeed: 'https://www.internethaber.com/rss',
    ),

    NewsSource(
      id: 'nethaber',
      name: 'Nethaber',
      shortName: 'Nethaber',
      tagline: 'Anlık haber ve gündem portalı',
      domain: 'nethaber.com',
      brandColor: Color(0xFF1565C0),
      primaryFeed: 'https://www.nethaber.com/rss',
    ),

    // ───── Ekonomi / Finans ─────
    // Yeni kullanıcının özellikle istediği finans kaynakları + sektörün
    // önde gelen gazete/portalları. Bigpara Hürriyet bünyesinde olsa da
    // içerik üretimi farklı, ayrı kaynak olarak listelendi.
    NewsSource(
      id: 'investingtr',
      name: 'Investing.com Türkçe',
      shortName: 'Investing TR',
      tagline: 'Borsa, döviz, kripto ve emtia haberleri',
      domain: 'tr.investing.com',
      brandColor: Color(0xFF1F73B7),
      primaryFeed: 'https://tr.investing.com/rss/news.rss',
      categoryFeeds: {
        // Investing'in `news_<id>.rss` pattern'ı her kategori için ayrı
        // feed döndürüyor (web fetch ile teyit edildi, Mayıs 2026).
        'ekonomi': 'https://tr.investing.com/rss/news.rss',
        'finans': 'https://tr.investing.com/rss/news_357.rss', // Borsa
      },
      recommended: true,
    ),

    NewsSource(
      id: 'bloomberght',
      name: 'Bloomberg HT',
      shortName: 'Bloomberg HT',
      tagline: 'Türkiye\'nin uluslararası finans kanalı',
      domain: 'bloomberght.com',
      brandColor: Color(0xFFFA8C16),
      primaryFeed: 'https://www.bloomberght.com/rss',
      recommended: true,
    ),

    NewsSource(
      id: 'dunyagazetesi',
      name: 'Dünya Gazetesi',
      shortName: 'Dünya',
      tagline: 'Ekonomi ve iş dünyası gazetesi',
      domain: 'dunya.com',
      brandColor: Color(0xFF143263),
      primaryFeed: 'https://www.dunya.com/rss',
    ),

    NewsSource(
      id: 'bigpara',
      name: 'Bigpara',
      shortName: 'Bigpara',
      tagline: 'Hürriyet bünyesinde finans portalı',
      domain: 'bigpara.hurriyet.com.tr',
      brandColor: Color(0xFF015B9F),
      primaryFeed: 'https://bigpara.hurriyet.com.tr/rss/',
    ),

    NewsSource(
      id: 'ekonomim',
      name: 'Ekonomim',
      shortName: 'Ekonomim',
      tagline: 'Eski "Dünya online" — ekonomi haberleri',
      domain: 'ekonomim.com',
      brandColor: Color(0xFF1A3D7D),
      primaryFeed: 'https://www.ekonomim.com/rss',
    ),

    // NOT: BirGün, Evrensel, Onedio, Haber7, Sporx, TGRT Haber, Yeni Akit,
    // T24, Kanal 7, Patronlar Dünyası, Forbes Türkiye Mayıs 2026 itibariyle
    // publik RSS yayını yapmıyor (404 ya da feed yerine HTML dönüyor).
    // DHA ve İHA sadece kurumsal abonelikle veriliyor — `mobil_haber` demo
    // aşamasında atlandılar.

    // ───── Teknoloji ─────
    NewsSource(
      id: 'webrazzi',
      name: 'Webrazzi',
      shortName: 'Webrazzi',
      tagline: 'Türkiye\'nin teknoloji yayını',
      domain: 'webrazzi.com',
      brandColor: Color(0xFFFF6B35),
      primaryFeed: 'https://webrazzi.com/feed/',
    ),

    NewsSource(
      id: 'shiftdelete',
      name: 'ShiftDelete.Net',
      shortName: 'ShiftDelete',
      tagline: 'Teknoloji incelemeleri ve haberleri',
      domain: 'shiftdelete.net',
      brandColor: Color(0xFFE91E63),
      primaryFeed: 'https://shiftdelete.net/feed/',
    ),

    NewsSource(
      id: 'donanimhaber',
      name: 'Donanım Haber',
      shortName: 'DH',
      tagline: 'Donanım ve teknoloji haberleri',
      domain: 'donanimhaber.com',
      brandColor: Color(0xFFFF3300),
      primaryFeed: 'https://www.donanimhaber.com/rss/tum/',
    ),

    NewsSource(
      id: 'webtekno',
      name: 'Webtekno',
      shortName: 'Webtekno',
      tagline: 'Türkiye\'nin teknoloji ve bilim portalı',
      domain: 'webtekno.com',
      brandColor: Color(0xFF00C853),
      primaryFeed: 'https://www.webtekno.com/rss.xml',
      recommended: true,
    ),

    NewsSource(
      id: 'chiponline',
      name: 'CHIP Online',
      shortName: 'CHIP',
      tagline: 'Teknoloji incelemeleri ve dergi içeriği',
      domain: 'chip.com.tr',
      brandColor: Color(0xFFE60000),
      primaryFeed: 'https://www.chip.com.tr/rss',
    ),

    NewsSource(
      id: 'tamindir',
      name: 'Tamindir',
      shortName: 'Tamindir',
      tagline: 'Teknoloji haberleri ve uygulama incelemeleri',
      domain: 'tamindir.com',
      brandColor: Color(0xFF4CAF50),
      primaryFeed: 'https://www.tamindir.com/feed/',
    ),

    // ───── Spor ─────
    NewsSource(
      id: 'fotomac',
      name: 'Fotomaç',
      shortName: 'Fotomaç',
      tagline: 'Spor — Türkiye\'nin önde gelen spor gazetesi',
      domain: 'fotomac.com.tr',
      brandColor: Color(0xFF1E88E5),
      primaryFeed: 'https://www.fotomac.com.tr/rss/anasayfa.xml',
    ),

    NewsSource(
      id: 'aspor',
      name: 'A Spor',
      shortName: 'A Spor',
      tagline: 'Futbol, basketbol ve diğer spor branşları',
      domain: 'aspor.com.tr',
      brandColor: Color(0xFFE30613),
      primaryFeed: 'https://www.aspor.com.tr/rss/anasayfa.xml',
      categoryFeeds: {
        'spor': 'https://www.aspor.com.tr/rss/futbol.xml',
      },
    ),

    // ───── Genel / magazin ─────
    NewsSource(
      id: 'posta',
      name: 'Posta',
      shortName: 'Posta',
      tagline: 'Gündem, magazin ve yaşam',
      domain: 'posta.com.tr',
      brandColor: Color(0xFFE2231A),
      primaryFeed: 'https://www.posta.com.tr/rss/anasayfa.xml',
    ),

    NewsSource(
      id: 'aksam',
      name: 'Akşam',
      shortName: 'Akşam',
      tagline: 'Genel haber, yorum',
      domain: 'aksam.com.tr',
      brandColor: Color(0xFF003366),
      primaryFeed: 'https://www.aksam.com.tr/rss/rss.asp',
    ),

    NewsSource(
      id: 'takvim',
      name: 'Takvim',
      shortName: 'Takvim',
      tagline: 'Gündem, magazin, spor',
      domain: 'takvim.com.tr',
      brandColor: Color(0xFFEC1C24),
      primaryFeed: 'https://www.takvim.com.tr/rss/anasayfa.xml',
    ),

    // ───── A Haber (TV + portal) ─────
    NewsSource(
      id: 'ahaber',
      name: 'A Haber',
      shortName: 'A Haber',
      tagline: 'Türkiye\'nin ilk HD haber kanalı',
      domain: 'ahaber.com.tr',
      brandColor: Color(0xFFE30613),
      primaryFeed: 'https://www.ahaber.com.tr/rss/news.xml',
      categoryFeeds: {
        'gundem': 'https://www.ahaber.com.tr/rss/gundem.xml',
        'ekonomi': 'https://www.ahaber.com.tr/rss/ekonomi.xml',
        'spor': 'https://www.ahaber.com.tr/rss/spor.xml',
        'dunya': 'https://www.ahaber.com.tr/rss/dunya.xml',
        'teknoloji': 'https://www.ahaber.com.tr/rss/teknoloji.xml',
        'yasam': 'https://www.ahaber.com.tr/rss/yasam.xml',
      },
      recommended: true,
    ),

    // ───── Star ─────
    NewsSource(
      id: 'star',
      name: 'Star',
      shortName: 'Star',
      tagline: 'Genel haber portalı',
      domain: 'star.com.tr',
      brandColor: Color(0xFF003366),
      primaryFeed: 'https://www.star.com.tr/rss/rss.asp',
    ),

    // ───── Bianet — bağımsız iletişim ağı ─────
    NewsSource(
      id: 'bianet',
      name: 'Bianet',
      shortName: 'Bianet',
      tagline: 'Bağımsız iletişim ağı — insan hakları odaklı',
      domain: 'bianet.org',
      brandColor: Color(0xFF008C8C),
      primaryFeed: 'https://bianet.org/bianet.rss',
      categoryFeeds: {
        'kultur': 'https://bianet.org/biamag.rss',
        'sanat': 'https://bianet.org/biamag.rss',
      },
    ),

    // ───── Mynet ─────
    NewsSource(
      id: 'mynet',
      name: 'Mynet',
      shortName: 'Mynet',
      tagline: 'Türkiye\'nin internet portalı',
      domain: 'mynet.com',
      brandColor: Color(0xFFE2231A),
      primaryFeed: 'https://www.mynet.com/haber/rss/sondakika',
    ),

    // ───── Haber Global ─────
    NewsSource(
      id: 'haberglobal',
      name: 'Haber Global',
      shortName: 'Haber Global',
      tagline: 'Küresel haber kanalı',
      domain: 'haberglobal.com.tr',
      brandColor: Color(0xFF0093D0),
      primaryFeed: 'https://haberglobal.com.tr/rss',
    ),

    // ───── Habertürk Genç ─────
    NewsSource(
      id: 'haberturkgenc',
      name: 'Habertürk Genç',
      shortName: 'HT Genç',
      tagline: 'Gençlere özel içerik akışı',
      domain: 'haberturk.com',
      brandColor: Color(0xFFFF6F00),
      primaryFeed: 'https://www.haberturk.com/rss/genc.xml',
    ),

    // ───── Uluslararası TR-English (Türkiye haberlerine yabancı bakış) ─────
    NewsSource(
      id: 'dailysabah',
      name: 'Daily Sabah',
      shortName: 'Daily Sabah',
      tagline: 'Turkey\'s English-language daily',
      domain: 'dailysabah.com',
      brandColor: Color(0xFFCC0000),
      primaryFeed: 'https://www.dailysabah.com/rss/homepage.xml',
      language: 'en',
      categoryFeeds: {
        'gundem': 'https://www.dailysabah.com/rss/category/politics',
      },
    ),

    NewsSource(
      id: 'hurriyetdaily',
      name: 'Hürriyet Daily News',
      shortName: 'HDN',
      tagline: 'Turkey in English — Hürriyet\'s int\'l edition',
      domain: 'hurriyetdailynews.com',
      brandColor: Color(0xFFE30613),
      primaryFeed: 'https://www.hurriyetdailynews.com/rss',
      language: 'en',
    ),

    NewsSource(
      id: 'aaenglish',
      name: 'AA English',
      shortName: 'AA EN',
      tagline: 'Anadolu Agency English service',
      domain: 'aa.com.tr',
      brandColor: Color(0xFF002B5C),
      primaryFeed: 'https://www.aa.com.tr/en/rss/default?cat=guncel',
      language: 'en',
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
