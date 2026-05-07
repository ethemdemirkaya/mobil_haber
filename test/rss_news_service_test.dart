import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobil_haber/data/models/news_source.dart';
import 'package:mobil_haber/data/repositories/rss_news_service.dart';

const String _trtFixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
<channel>
<title>TRT Haber</title>
<link>https://www.trthaber.com/</link>
<item>
<guid>https://www.trthaber.com/haber/gundem/test-1.html</guid>
<pubDate>Thu, 07 May 2026 18:50:00 +0300</pubDate>
<title>Cumhurbaşkanı Erdoğan açıklama yaptı</title>
<description><![CDATA[<img src="https://example.com/img.jpg"/>Türkiye gündem haberleri özet]]></description>
<media:content url="https://example.com/img.jpg" type="image/jpeg"/>
<link>https://www.trthaber.com/haber/gundem/test-1.html</link>
</item>
<item>
<guid>https://www.trthaber.com/haber/spor/test-2.html</guid>
<pubDate>Thu, 07 May 2026 17:30:00 +0300</pubDate>
<title>Galatasaray maç sonucu</title>
<description><![CDATA[Spor haberleri Türkiye süper lig]]></description>
<link>https://www.trthaber.com/haber/spor/test-2.html</link>
</item>
</channel>
</rss>
''';

void main() {
  test('RssNewsService parses RSS 2.0 with media tag', () async {
    final mock = MockClient((req) async {
      return http.Response(_trtFixture, 200,
          headers: {'content-type': 'application/rss+xml; charset=utf-8'});
    });
    final service = RssNewsService(httpClient: mock);
    final source = NewsSourceCatalog.byId('trthaber')!;

    final articles = await service.fetchOne(source, limit: 10);

    expect(articles.length, 2);
    expect(articles.first.title, contains('Erdoğan'));
    expect(articles.first.imageUrl, 'https://example.com/img.jpg');
    expect(articles.first.sourceName, source.name);
    expect(articles.first.sourceUrl, isNotEmpty);
    expect(articles.first.publishedAt.year, 2026);

    // Kategori kelime taraması: "spor" "Galatasaray" → spor
    expect(articles[1].categoryId, 'spor');
  });

  test('aggregate sırasında kötü bir kaynak akışı bozmaz', () async {
    final mock = MockClient((req) async {
      // debugPrint('mock: ${req.url}');
      if (req.url.toString().contains('trthaber')) {
        return http.Response(
          _trtFixture,
          200,
          headers: {'content-type': 'application/rss+xml; charset=utf-8'},
        );
      }
      return http.Response('boom', 500);
    });
    final service = RssNewsService(httpClient: mock);
    final sources = [
      NewsSourceCatalog.byId('trthaber')!,
      NewsSourceCatalog.byId('aa')!,
    ];

    final articles = await service.aggregate(sources, perSource: 5);
    expect(articles, isNotEmpty);
    // Hatalı AA atıldı, TRT kaldı.
    expect(articles.every((a) => a.sourceName == 'TRT Haber'), isTrue);
  });
}
