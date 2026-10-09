import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pusula_news/data/models/bias_report.dart';
import 'package:pusula_news/data/models/qa_answer.dart';
import 'package:pusula_news/data/repositories/article_text_extractor.dart';
import 'package:pusula_news/data/repositories/language_signal_analyzer.dart';

const _para1 =
    'Malatya Battalgazi merkezli 5,2 büyüklüğündeki deprem sabah saatlerinde '
    'meydana geldi ve çevre illerden de hissedildi.';
const _para2 =
    'AFAD yaptığı açıklamada depremin 7 kilometre derinlikte gerçekleştiğini, '
    'ilk belirlemelere göre can kaybı bulunmadığını bildirdi.';
const _para3 =
    'Vali, ekiplerin hasar tespit çalışmalarına başladığını ve vatandaşların '
    'hasarlı binalara girmemesi gerektiğini söyledi.';
const _para4 =
    'Kandilli Rasathanesi ise depremin ardından bölgede onlarca artçı '
    'sarsıntı kaydedildiğini ve en büyüğünün 3,8 olduğunu duyurdu.';

void main() {
  group('ArticleTextExtractor', () {
    test('article bölgesindeki paragrafları çıkarır, gürültüyü atar', () {
      const html = '''
<html><head><script>var x = "<p>script içindeki paragraf metni burada uzun uzun yazıyor ve atılmalı</p>";</script></head>
<body>
<nav><p>Ana sayfa Gündem Spor Ekonomi Dünya Teknoloji Sağlık Yaşam Kültür Sanat</p></nav>
<article>
  <h1>Malatya'da deprem</h1>
  <p>$_para1</p>
  <p><a href="/x">İlgili haber: Malatya'da geçen yıl yaşanan depremler ve sonuçları listesi</a></p>
  <p>$_para2</p>
  <p>Kısa satır.</p>
  <p>$_para3</p>
  <p>$_para4</p>
  <p>Bu haberin tüm hakları saklıdır, kaynak gösterilmeden izinsiz kullanılamaz ve çoğaltılamaz.</p>
</article>
<footer><p>Çerez politikamızı okumak için tıklayın, sitemizi kullanarak kabul etmiş olursunuz.</p></footer>
</body></html>
''';
      final text = ArticleTextExtractor.extractFromHtml(html);

      expect(text, isNotNull);
      expect(text, contains('AFAD yaptığı açıklamada'));
      expect(text!.split('\n\n'), [_para1, _para2, _para3, _para4]);
    });

    test('extract() ağ isteğinden sonra tamamlanır (kendini bekleme hatası)',
        () async {
      const html = '<body><p>$_para1</p><p>$_para2</p>'
          '<p>$_para3</p><p>$_para4</p></body>';
      final extractor = ArticleTextExtractor(
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(html),
              200,
            )),
      );
      final text = await extractor
          .extract('https://ornek.com/haber-1')
          .timeout(const Duration(seconds: 2));
      expect(text, contains('AFAD'));
      // İkinci çağrı cache'ten döner.
      expect(await extractor.extract('https://ornek.com/haber-1'), text);
    });

    test('yeterli gövde metni yoksa null döner', () {
      const html =
          '<html><body><article><p>$_para1</p><p>$_para2</p></article></body></html>';
      expect(ArticleTextExtractor.extractFromHtml(html), isNull);
    });

    test('article etiketi yoksa gövdeden çıkarır ve entity çözer', () {
      const html = '<body><div><p>$_para1 &quot;Sakin olun&quot; dedi.</p>'
          '<p>$_para2</p><p>$_para3</p><p>$_para4</p></div></body>';
      final text = ArticleTextExtractor.extractFromHtml(html);
      expect(text, contains('"Sakin olun"'));
    });
  });

  group('LanguageSignalAnalyzer', () {
    const analyzer = LanguageSignalAnalyzer();

    test('nötr manşet düşük skor alır', () {
      final r = analyzer.analyze(
        title: 'AFAD: Malatya\'daki depremde can kaybı yok',
        body: _para2,
      );
      expect(r.score, lessThanOrEqualTo(25));
      expect(r.cues, isEmpty);
    });

    test('duygu yüklü, tıklama tuzağı manşet yüksek skor alır', () {
      final r = analyzer.analyze(
        title: 'SKANDAL! İşte herkesin konuştuğu o rezalet görüntüler',
      );
      expect(r.score, greaterThan(50));
      expect(r.cues.map((c) => c.text),
          containsAll(['skandal', 'rezalet', 'işte', '!']));
    });

    test('kısaltmalar vurgulu büyük harf sayılmaz', () {
      final r = analyzer.analyze(title: 'TBMM ve AFAD, NATO zirvesini görüştü');
      expect(
        r.cues.where((c) => c.kind == LanguageCueKind.typographic),
        isEmpty,
      );
    });

    test('düz anlamlı kelimeler yanlış sinyal üretmez', () {
      final r = analyzer.analyze(
        title: 'Bomba yüklü araç etkisiz hale getirildi',
        body: 'Deprem felaketinin ardından resmen açıklandı.',
      );
      expect(r.score, 0);
    });
  });

  group('QaAnswer.parse', () {
    test('etiketleri ayrıştırır', () {
      final a = QaAnswer.parse('[HABERDE] Deprem 5,2 büyüklüğünde.');
      expect(a.grounding, QaGrounding.article);
      expect(a.text, 'Deprem 5,2 büyüklüğünde.');

      expect(QaAnswer.parse('[GENEL BİLGİ]\nBölge fay hattında.').grounding,
          QaGrounding.background);
      expect(QaAnswer.parse('[ALAKASIZ] Bu soru haberle ilgili değil.')
          .grounding, QaGrounding.offTopic);
    });

    test('etiket yoksa temkinli davranıp genel bilgi sayar', () {
      expect(QaAnswer.parse('Bir cevap').grounding, QaGrounding.background);
    });
  });

  group('BiasReport.assessConfidence', () {
    test('aynı bant ve doğrulanan alıntılar → yüksek güven', () {
      expect(
        BiasReport.assessConfidence(
            llmScore: 70, lexicalScore: 60, claimedCues: 2, verifiedCues: 2),
        BiasConfidence.high,
      );
    });

    test('uzak bantlar ve uydurma alıntılar → düşük güven', () {
      expect(
        BiasReport.assessConfidence(
            llmScore: 85, lexicalScore: 0, claimedCues: 3, verifiedCues: 0),
        BiasConfidence.low,
      );
    });

    test('alıntısız nötr sonuç, nötr sinyalle → yüksek güven', () {
      expect(
        BiasReport.assessConfidence(
            llmScore: 10, lexicalScore: 0, claimedCues: 0, verifiedCues: 0),
        BiasConfidence.high,
      );
    });

    test('eski kayıt formatı okunabiliyor', () {
      final r = BiasReport.tryParse(
          {'score': 40, 'label': 'Hafif yönlü', 'cues': [], 'summary': 'x'});
      expect(r, isNotNull);
      expect(r!.lexicalScore, isNull);
      expect(r.confidence, BiasConfidence.low);
    });
  });
}
