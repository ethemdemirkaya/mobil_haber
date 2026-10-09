import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pusula_news/data/models/news_source.dart';
import 'package:pusula_news/data/repositories/article_text_extractor.dart';
import 'package:pusula_news/data/repositories/rss_news_service.dart';
import 'package:pusula_news/data/sources/fetch_utils.dart';
import 'package:pusula_news/data/sources/haberturk_fetcher.dart';
import 'package:pusula_news/data/sources/news_aggregator.dart';
import 'package:pusula_news/data/sources/wordpress_fetcher.dart';

// Gerçek yanıtların yapısını taklit eden sentetik veriler (yayıncı
// metinleri depoya konmaz).
final _wpPost = {
  'id': 101,
  'link': 'https://www.diken.com.tr/ornek-haber/',
  'date_gmt': '2026-10-09T22:30:00',
  'title': {'rendered': 'Örnek &#8216;haber&#8217; başlığı'},
  'excerpt': {'rendered': '<p>Kısa özet cümlesi.</p>\n'},
  'content': {
    'rendered': '<p>Birinci paragraf metni.</p><figure><img src="x"/>'
        '<figcaption>alt yazı</figcaption></figure><p>İkinci &amp; son '
        'paragraf.</p>'
  },
  '_embedded': {
    'wp:featuredmedia': [
      {
        'source_url': 'https://www.diken.com.tr/wp-content/tam.jpg',
        'media_details': {
          'sizes': {
            'large': {'source_url': 'https://www.diken.com.tr/wp-content/buyuk.jpg'}
          }
        }
      }
    ]
  },
};

Map<String, Object?> _htItem(int id, String type,
        {Object? ad, String time = '2026-10-10 00:47:44'}) =>
    {
      'newsId': id,
      'type': type,
      'title': 'Habertürk haberi $id',
      'spot': 'Spot $id',
      'officialAdId': ad,
      'absoluteUrl': 'https://www.haberturk.com/gundem/haber-$id',
      'updatedDateTime': time,
      'category': {
        'items': [
          {'kod': 'gundem'}
        ]
      },
      'image': {'imageUrlBase': 'https://im.haberturk.com/l/$id/jpg/'},
    };

const _rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
<item><title>RSS haberi</title><link>https://www.diken.com.tr/rss-haberi/</link>
<pubDate>Thu, 09 Oct 2026 20:00:00 +0000</pubDate><description>Özet</description></item>
</channel></rss>''';

void main() {
  group('fetch_utils', () {
    test('izleme parametreleri kimliği değiştirmez', () {
      expect(
        articleIdForUrl(
            'https://www.bbc.com/turkce/articles/x?at_medium=RSS&at_campaign=rss'),
        articleIdForUrl('https://www.bbc.com/turkce/articles/x'),
      );
      expect(articleIdForUrl('https://a.com/x?id=1'),
          isNot(articleIdForUrl('https://a.com/x?id=2')));
    });

    test('htmlToParagraphs paragrafları korur, figürü atar', () {
      expect(htmlToParagraphs(_wpPost['content'].toString().isEmpty ? '' :
          (_wpPost['content'] as Map)['rendered'] as String),
          'Birinci paragraf metni.\n\nİkinci & son paragraf.');
    });
  });

  test('WordPress yazısı: başlık, UTC tarih, büyük görsel, tam gövde', () {
    final a = WordPressFetcher.parsePost(
        _wpPost, NewsSourceCatalog.byId('diken')!)!;
    expect(a.title, 'Örnek ‘haber’ başlığı');
    expect(a.publishedAt, DateTime.utc(2026, 10, 9, 22, 30));
    expect(a.imageUrl, endsWith('buyuk.jpg'));
    expect(a.content, contains('İkinci & son paragraf.'));
    expect(a.summary, 'Kısa özet cümlesi.');
    expect(a.sourceId, 'diken');
  });

  test('Habertürk: reklam/ilan elenir, tekrar kaldırılır, saat UTC+3', () {
    final json = {
      'body': {
        'content': {
          'items': {
            'mainSlider': {
              'items': [_htItem(1, 'news'), _htItem(2, 'photoNews')]
            },
            'itemList1': {
              'items': [
                _htItem(1, 'news'), // tekrar
                _htItem(3, 'officialAnnouncement'),
                _htItem(4, 'news', ad: 99),
              ]
            },
          }
        }
      }
    };
    final list = HaberturkFetcher.parseResponse(
        json, NewsSourceCatalog.byId('haberturk')!);
    expect(list.map((a) => a.title),
        unorderedEquals(['Habertürk haberi 1', 'Habertürk haberi 2']));
    expect(list.first.publishedAt, DateTime.utc(2026, 10, 9, 21, 47, 44));
    expect(list.first.imageUrl, endsWith('/jpg/640x360'));
  });

  group('NewsAggregator planı', () {
    test('API başarısızsa RSS\'e düşer', () async {
      final client = MockClient((req) async {
        if (req.url.path.contains('wp-json')) return http.Response('x', 503);
        return http.Response.bytes(utf8.encode(_rss), 200);
      });
      final agg = NewsAggregator(
          client: client, rss: RssNewsService(httpClient: client));
      final out = await agg.fetchSource(NewsSourceCatalog.byId('diken')!,
          limit: 5);
      expect(out.method, 'RSS');
      expect(out.articles.single.title, 'RSS haberi');
      expect(out.errors.single, startsWith('WordPress API'));
    });

    test('API çalışıyorsa onu kullanır; RSS\'e hiç gidilmez', () async {
      final hosts = <String>[];
      final client = MockClient((req) async {
        hosts.add(req.url.path);
        return http.Response.bytes(utf8.encode(jsonEncode([_wpPost])), 200);
      });
      final agg = NewsAggregator(
          client: client, rss: RssNewsService(httpClient: client));
      final out = await agg.fetchSource(NewsSourceCatalog.byId('diken')!,
          limit: 5);
      expect(out.method, 'WordPress API');
      expect(hosts.every((p) => p.contains('wp-json')), isTrue);
    });

    test('API\'si olmayan kaynak doğrudan RSS', () {
      final agg = NewsAggregator();
      expect(agg.planFor(NewsSourceCatalog.byId('aa')!).map((f) => f.label),
          ['RSS']);
      expect(
          agg.planFor(NewsSourceCatalog.byId('haberturk')!).map((f) => f.label),
          ['Habertürk API', 'RSS']);
    });

    test('kategori sunamayan API atlanır (Habertürk spor → RSS)', () {
      final ht = NewsAggregator()
          .planFor(NewsSourceCatalog.byId('haberturk')!)
          .first;
      expect(ht.supportsCategory('spor'), isFalse);
      expect(ht.supportsCategory('dunya'), isTrue);
    });
  });

  group('gömülü veri okuyucuları', () {
    test('BBC __NEXT_DATA__: yalnızca metin bloklarının paragrafları', () {
      final p1 = 'Birinci paragraf ' * 8;
      final p2 = 'İkinci paragraf ' * 8;
      final data = {
        'props': {
          'pageProps': {
            'pageData': {
              'content': {
                'model': {
                  'blocks': [
                    {'type': 'headline', 'model': {'blocks': [{'type': 'paragraph', 'model': {'text': 'BAŞLIK'}}]}},
                    {'type': 'text', 'model': {'blocks': [{'type': 'paragraph', 'model': {'text': p1}}]}},
                    {'type': 'image', 'model': {'blocks': [{'type': 'paragraph', 'model': {'text': 'altyazı'}}]}},
                    {'type': 'text', 'model': {'blocks': [{'type': 'paragraph', 'model': {'text': p2}}]}},
                  ]
                }
              }
            }
          }
        }
      };
      final html = '<script id="__NEXT_DATA__" type="application/json">'
          '${jsonEncode(data)}</script>';
      expect(ArticleTextExtractor.extractFromHtml(html),
          '${p1.trim()}\n\n${p2.trim()}');
    });

    test('Euronews: plainText alanı kaçışlarıyla çözülür', () {
      final body = 'Sendikalar yürüdü. ' * 15;
      final html = '<script id="euronews-initial-server-data">'
          'window.getInitialServerData = function(){ return {"entities":'
          '{"article":{"plainText":${jsonEncode('$body\n"Alıntı" bitti.')}}}}; }'
          '</script>';
      final out = ArticleTextExtractor.extractFromHtml(html)!;
      expect(out, contains('"Alıntı" bitti.'));
      expect(out.split('\n\n'), hasLength(2));
    });
  });
}
