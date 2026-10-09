import 'package:flutter_test/flutter_test.dart';

import 'package:pusula_news/core/utils/turkish_text.dart';
import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/data/repositories/category_classifier.dart';

void main() {
  const c = CategoryClassifier();

  String classify(String title, [String summary = '', String url = '']) =>
      c.classify(title: title, summary: summary, url: url);

  group('turkish_text', () {
    test('trLower Türkçe I/İ kurallarını uygular', () {
      expect(trLower('ALTIN'), 'altın');
      expect(trLower('SAĞLIK'), 'sağlık');
      expect(trLower('İSTANBUL'), 'istanbul');
      expect(trLower('Zekâ'), 'zeka');
    });

    test('trTokens kesme işaretinde böler', () {
      expect(trTokens("Erdoğan'ın açıklaması"), ['erdoğan', 'ın', 'açıklaması']);
    });

    test('stemMatches yalnızca geçerli ek zincirini kabul eder', () {
      expect(stemMatches('maçta', 'maç'), isTrue);
      expect(stemMatches('seçimlerde', 'seçim'), isTrue);
      expect(stemMatches('aşıyı', 'aşı'), isTrue);
      expect(stemMatches('operasyon', 'opera'), isFalse);
      expect(stemMatches('aşırı', 'aşı'), isFalse);
      expect(stemMatches('uzayan', 'uzay'), isFalse);
    });
  });

  group('CategoryClassifier', () {
    test('alt-dize yanlış pozitifleri artık oluşmuyor', () {
      expect(classify('45 yaşındaki adam evinde ölü bulundu'), 'gundem');
      expect(classify('İstanbul\'da uyuşturucu operasyonu: 12 gözaltı'),
          'gundem');
      expect(classify('Sıcaklıklar mevsim normallerinin altında seyredecek'),
          'gundem');
    });

    test('büyük harf manşetler doğru sınıflanır', () {
      expect(classify('GRAM ALTIN FİYATI REKOR KIRDI'), 'ekonomi');
      expect(classify('SAĞLIK BAKANLIĞI YENİ AŞI TAKVİMİNİ AÇIKLADI'),
          'saglik');
    });

    test('ekli kelimeler eşleşir', () {
      expect(classify('Galatasaray derbide Fenerbahçe\'yi yendi'), 'spor');
      expect(classify('Merkez Bankası faizi sabit tuttu'), 'ekonomi');
    });

    test('URL segmenti anahtar kelimelerden önce gelir, slug sayılmaz', () {
      expect(
        classify('Gündemi sarsan gelişme', '',
            'https://www.ntv.com.tr/spor/gundemi-sarsan-gelisme'),
        'spor',
      );
      expect(
        classify('Kupa heyecanı', '',
            'https://site.com/haber/dunya-kupasi-heyecani'),
        'gundem',
      );
    });

    test('dayatılan kategori ve RSS etiketi önceliklidir', () {
      expect(
        c.classify(explicit: 'bilim', title: 'Galatasaray kazandı', summary: ''),
        'bilim',
      );
      expect(
        c.classify(
          title: 'Galatasaray kazandı',
          summary: '',
          rssCategories: const ['Ekonomi'],
        ),
        'ekonomi',
      );
    });

    test('tek zayıf sinyal kategori değiştirmez', () {
      // "gol" başlıkta değil, yalnızca özette → 1 puan < eşik.
      expect(classify('Valilik açıklama yaptı', 'Bir gol gibi haber'),
          'gundem');
    });
  });

  test('Article.matchesQuery Türkçe karakterden bağımsız', () {
    final a = Article(
      id: '1',
      title: 'SAĞLIK BAKANLIĞI AÇIKLADI',
      summary: 'İstanbul',
      content: '',
      categoryId: 'saglik',
      imageUrl: '',
      author: '',
      publishedAt: DateTime(2026),
      readMinutes: 1,
    );
    expect(a.matchesQuery('saglik'), isTrue);
    expect(a.matchesQuery('sağlık bakanlığı'), isTrue);
    expect(a.matchesQuery('istanbul'), isTrue);
  });
}
