import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pusula_news/data/local/local_db.dart';
import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/data/models/news_source.dart';
import 'package:pusula_news/data/repositories/article_text_extractor.dart';
import 'package:pusula_news/data/repositories/category_classifier.dart';
import 'package:pusula_news/data/repositories/news_cluster_service.dart';
import 'package:pusula_news/data/repositories/rss_news_service.dart';
import 'package:pusula_news/providers/news_provider.dart';

final _now = DateTime(2026, 10, 9, 12);
var _seq = 0;

Article _a(String source, String title,
    {String image = '', Duration ago = Duration.zero, String cat = 'gundem'}) {
  _seq++;
  return Article(
    id: 'f$_seq',
    title: title,
    summary: '',
    content: '',
    categoryId: cat,
    imageUrl: image,
    author: source,
    publishedAt: _now.subtract(ago),
    readMinutes: 1,
    sourceName: source,
  );
}

void main() {
  group('CategoryClassifier kaynak varsayılanı', () {
    const c = CategoryClassifier();

    test('ekonomi kaynağındaki şirket haberi gündeme düşmez', () {
      expect(
        c.classify(
          title: 'RLI Corp. dört üst düzey yöneticisini terfi ettirdi',
          summary: '',
          sourceDefault: 'ekonomi',
        ),
        'ekonomi',
      );
    });

    test('zayıf başka sinyal kaynak varsayılanını ezmez', () {
      expect(
        c.classify(
          title: 'Fenerbahçe hisseleri borsada yükseldi',
          summary: '',
          sourceDefault: 'ekonomi',
        ),
        'ekonomi',
      );
    });

    test('genel kaynakta basketbol haberi spora gider', () {
      expect(
        c.classify(title: "Anadolu Efes, Olympiakos'a kaybetti", summary: ''),
        'spor',
      );
    });

    test('konu kaynakları katalogda işaretli, Investing varsayılan değil', () {
      expect(NewsSourceCatalog.byId('investingtr')!.defaultCategory, 'ekonomi');
      expect(NewsSourceCatalog.byId('aspor')!.defaultCategory, 'spor');
      expect(NewsSourceCatalog.byId('aa')!.defaultCategory, isNull);
      expect(NewsSourceCatalog.byId('investingtr')!.recommended, isFalse);
      expect(NewsSourceCatalog.byId('cumhuriyet')!.recommended, isTrue);
    });
  });

  group('ArticleTextExtractor', () {
    test('JSON-LD articleBody paragraf taramasından önce gelir', () {
      const body = 'Trendyol Süper Lig\'in 7. haftasında Kasımpaşa deplasmanda '
          'Galatasaray\'a 3-1 yenildi. Lacivert-beyazlılar böylece sezonda '
          'ligde ilk kez mağlup oldu. Bu sonuçla Kasımpaşa puanını 15\'te '
          'bıraktı ve zirve yarışında geriye düştü.';
      const html = '<html><head><script type="application/ld+json">'
          '{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},'
          '{"@type":"NewsArticle","articleBody":"$body"}]}</script></head>'
          '<body><p>Kısa menü metni</p></body></html>';
      expect(ArticleTextExtractor.extractFromHtml(html), body);
    });

    test('403 dönen siteye ikinci kez istek atılmaz', () async {
      var calls = 0;
      final extractor = ArticleTextExtractor(
        client: MockClient((_) async {
          calls++;
          return http.Response('engellendi', 403);
        }),
      );
      expect(await extractor.extract('https://engelli.ornek/haber-1'), isNull);
      expect(extractor.isBlocked('https://engelli.ornek/haber-2'), isTrue);
      expect(await extractor.extract('https://engelli.ornek/haber-2'), isNull);
      expect(calls, 1);
    });
  });

  group('İlgili haberler', () {
    const service = NewsClusterService();

    test('benzer olanı bulur, alakasızı ve kopyayı getirmez', () {
      final target = _a('Investing', 'RLI Corp. dört üst düzey yöneticisini terfi ettirdi');
      final pool = [
        target,
        _a('Sözcü', "İlkay Gündoğan'dan olay cevap: Oynamıyorum"),
        _a('Bloomberg', 'RLI Corp. yönetiminde terfi: dört yönetici yükseldi'),
        _a('AA', 'RLI Corp. dört üst düzey yöneticisini terfi ettirdi'),
      ];
      final related = service.mostSimilar(target, pool);
      expect(related.map((a) => a.sourceName), ['Bloomberg']);
    });
  });

  group('Ana sayfa tekrarları', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalDb.useInMemoryForTests(databaseFactoryFfi);
    });

    test('manşet farklı kaynaklardan, görselli; liste onları tekrarlamaz',
        () async {
      // Aynı kaynaktan iki, farklı kaynaklardan birer haber.
      String item(String title, String img, int min) => '''
<item><title>$title</title><link>https://ornek.com/${title.hashCode}</link>
<pubDate>Thu, 09 Oct 2026 ${(11 - min ~/ 60).toString().padLeft(2, '0')}:${(59 - min % 60).toString().padLeft(2, '0')}:00 +0000</pubDate>
${img.isEmpty ? '' : '<enclosure url="$img" type="image/jpeg"/>'}
<description>Özet</description></item>''';
      final feeds = {
        'trthaber': '<rss><channel>'
            '${item('TRT birinci haber', 'https://img/1.jpg', 1)}'
            '${item('TRT ikinci haber', 'https://img/2.jpg', 2)}'
            '</channel></rss>',
        'aa': '<rss><channel>'
            '${item('AA görselsiz haber', '', 3)}'
            '${item('AA görselli haber', 'https://img/3.jpg', 4)}'
            '</channel></rss>',
      };
      final client = MockClient((req) async {
        final key = feeds.keys.firstWhere(
          (k) => req.url.host.contains(k == 'aa' ? 'aa.com' : 'trthaber'),
        );
        return http.Response.bytes(
            feeds[key]!.codeUnits.map((c) => c & 0xff).toList(), 200);
      });
      final provider =
          NewsProvider(rssService: RssNewsService(httpClient: client));
      await provider.applySources([
        NewsSourceCatalog.byId('trthaber')!,
        NewsSourceCatalog.byId('aa')!,
      ]);

      final featured = provider.featured;
      expect(featured.map((a) => a.sourceName).toSet().length,
          featured.length, reason: 'her kaynaktan en fazla bir manşet');
      expect(featured.every((a) => a.imageUrl.isNotEmpty), isTrue);
      final featuredIds = featured.map((a) => a.id).toSet();
      expect(provider.homeFeed.any((a) => featuredIds.contains(a.id)), isFalse);
      expect(provider.homeFeed.length + featured.length,
          provider.articles.length);
    });
  });
}
