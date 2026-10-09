import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pusula_news/data/models/news_source.dart';
import 'package:pusula_news/data/repositories/rss_news_service.dart';
import 'package:pusula_news/providers/news_provider.dart';

const String _fixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
<item>
<title>Test haberi</title>
<link>https://www.trthaber.com/haber/gundem/test-1.html</link>
<pubDate>Thu, 07 May 2026 18:50:00 +0300</pubDate>
<description>Özet</description>
</item>
</channel></rss>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('aynı kaynaklarla eşzamanlı çağrılar tek çekim yapar', () async {
    var requests = 0;
    final client = MockClient((req) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(_fixture, 200);
    });
    final provider =
        NewsProvider(rssService: RssNewsService(httpClient: client));
    final sources = [NewsSourceCatalog.byId('trthaber')!];

    await Future.wait([
      provider.applySources(sources),
      provider.applySources(sources),
      provider.refresh(),
    ]);

    expect(requests, 1);
    expect(provider.articles, hasLength(1));
    expect(provider.unavailable, isFalse);
  });

  test('ağ ve cache yoksa sahte veri yerine unavailable olur', () async {
    final client = MockClient((req) async => http.Response('boom', 500));
    final provider =
        NewsProvider(rssService: RssNewsService(httpClient: client));

    await provider.applySources([NewsSourceCatalog.byId('trthaber')!]);

    expect(provider.articles, isEmpty);
    expect(provider.unavailable, isTrue);
    expect(provider.offline, isFalse);
  });
}
