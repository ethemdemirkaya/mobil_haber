import 'package:flutter_test/flutter_test.dart';

import 'package:pusula_news/core/utils/turkish_text.dart';
import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/data/repositories/news_cluster_service.dart';

final _now = DateTime(2026, 10, 9, 12);
var _seq = 0;

Article _a(String source, String title,
    {String summary = '', Duration ago = Duration.zero}) {
  _seq++;
  return Article(
    id: 'a$_seq',
    title: title,
    summary: summary,
    content: '',
    categoryId: 'gundem',
    imageUrl: '',
    author: source,
    publishedAt: _now.subtract(ago),
    readMinutes: 1,
    sourceName: source,
  );
}

/// Aynı gün yayınlanmış, birbiriyle ilgisiz arka plan haberleri — IDF'nin
/// gerçekçi olması için.
List<Article> _noise() => [
      _a('X', 'Merkez Bankası politika faizini yüzde 40\'ta sabit tuttu'),
      _a('Y', 'İstanbul\'da yarın sağanak yağış bekleniyor'),
      _a('Z', 'Yeni iPhone modeli Türkiye\'de satışa çıktı'),
      _a('W', 'Ankara\'da trafik kazası: 3 yaralı'),
      _a('V', 'Asgari ücret görüşmeleri yarın başlıyor'),
      _a('U', 'NASA Mars\'a yeni keşif aracı gönderiyor'),
    ];

void main() {
  const service = NewsClusterService();

  group('stemTr', () {
    test('ekli hâller aynı köke iner', () {
      expect(stemTr('seçimlerde'), stemTr('seçim'));
      expect(stemTr('seçimin'), stemTr('seçim'));
      expect(stemTr('bakanı'), stemTr('bakan'));
      expect(stemTr('depremde'), stemTr('deprem'));
    });

    test('kısa köklere dokunmaz', () {
      expect(stemTr('seç'), 'seç');
      expect(stemTr('maçı'), 'maçı');
    });
  });

  test('aynı olayı farklı ifadelerle veren kaynaklar kümelenir', () {
    final quake = [
      _a('AA', 'Malatya\'da 5,2 büyüklüğünde deprem',
          summary: 'AFAD, Malatya Battalgazi merkezli depremin 7 kilometre '
              'derinlikte meydana geldiğini açıkladı.'),
      _a('NTV', 'Malatya Battalgazi\'de korkutan deprem',
          summary: 'AFAD verilerine göre deprem 5,2 büyüklüğünde.',
          ago: const Duration(minutes: 20)),
      _a('BBC Türkçe', 'AFAD: Malatya\'daki depremde can kaybı yok',
          ago: const Duration(minutes: 50)),
    ];
    final clusters =
        service.findClusters([...quake, ..._noise()], now: _now);

    expect(clusters, hasLength(1));
    expect(clusters.first.sourceCount, 3);
    expect(
      clusters.first.articles.map((a) => a.id).toSet(),
      quake.map((a) => a.id).toSet(),
    );
  });

  test('ortak genel kelime üzerinden zincirleme olmaz', () {
    // v1 (single-linkage) A~B, B~C üzerinden üçünü birleştirebiliyordu.
    final articles = [
      _a('AA', 'Galatasaray Avrupa\'da tur atladı'),
      _a('NTV', 'Galatasaray tur atladı, Avrupa\'da yoluna devam ediyor'),
      _a('T24', 'Avrupa Birliği Türkiye raporunu açıkladı'),
      _a('BBC Türkçe', 'AB raporu: Avrupa Birliği hukuk devleti uyarısı'),
      ..._noise(),
    ];
    final clusters = service.findClusters(articles, now: _now);

    expect(clusters, hasLength(2));
    for (final c in clusters) {
      expect(c.sourceCount, 2);
    }
  });

  test('aynı kaynağın iki haberi tek başına küme oluşturmaz', () {
    final articles = [
      _a('AA', 'Malatya\'da deprem'),
      _a('AA', 'Malatya depremi sonrası AFAD açıklaması',
          ago: const Duration(minutes: 30)),
      ..._noise(),
    ];
    expect(service.findClusters(articles, now: _now), isEmpty);
  });

  test('zaman penceresi dışındaki haberler kümelenmez', () {
    final articles = [
      _a('AA', 'Malatya\'da 5,2 büyüklüğünde deprem'),
      _a('NTV', 'Malatya\'da 5,2 büyüklüğünde deprem',
          ago: const Duration(hours: 48)),
      ..._noise(),
    ];
    expect(service.findClusters(articles, now: _now), isEmpty);
  });

  test('gündem skoru tazeliği ve kaynak sayısını ölçer', () {
    final fresh = service.findClusters([
      _a('AA', 'Malatya\'da 5,2 büyüklüğünde deprem'),
      _a('NTV', 'Malatya\'da 5,2 büyüklüğünde deprem meydana geldi'),
      ..._noise(),
    ], now: _now);
    final stale = service.findClusters([
      _a('AA', 'Malatya\'da 5,2 büyüklüğünde deprem',
          ago: const Duration(hours: 12)),
      _a('NTV', 'Malatya\'da 5,2 büyüklüğünde deprem meydana geldi',
          ago: const Duration(hours: 12)),
      ..._noise(),
    ], now: _now);

    expect(fresh.single.hotScore, closeTo(2.0, 0.01));
    expect(stale.single.hotScore, closeTo(0.5, 0.01));
  });

  test('isolate yolu senkron sonuçla aynı', () async {
    final articles = [
      for (var i = 0; i < 50; i++) ...[
        _a('AA', 'Olay $i kentinde büyük yangın çıktı'),
        _a('NTV', 'Olay $i kentindeki yangın kontrol altına alındı'),
      ],
    ];
    final sync = service.findClusters(articles, now: _now);
    final async = await service.findClustersAsync(articles, now: _now);
    expect(async.length, sync.length);
  });
}
