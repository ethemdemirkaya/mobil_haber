import 'package:flutter_test/flutter_test.dart';

import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/data/repositories/daily_briefing_service.dart';

var _seq = 0;
Article _a(String source, String cat, {String title = '', String summary = ''}) {
  _seq++;
  return Article(
    id: 'b$_seq',
    title: title.isEmpty ? 'Haber $_seq' : title,
    summary: summary,
    content: '',
    categoryId: cat,
    imageUrl: '',
    author: source,
    publishedAt: DateTime(2026, 10, 9, 12).subtract(Duration(minutes: _seq)),
    readMinutes: 1,
    sourceName: source,
  );
}

void main() {
  final service = DailyBriefingService();

  group('splitIntoUtterances', () {
    test('sıra sayısında ("7. hafta") bölmez', () {
      final parts = service.splitIntoUtterances(
        "Süper Lig'in 7. haftasında Kasımpaşa yenildi. Galatasaray zirvede.",
        maxChars: 40,
      );
      expect(parts.first, "Süper Lig'in 7. haftasında Kasımpaşa yenildi.");
    });

    test('kısaltmadan ("Dr.") sonra bölmez', () {
      final parts = service.splitIntoUtterances(
        'Açıklamayı Dr. Ahmet Yılmaz yaptı. Toplantı yarın.',
        maxChars: 30,
      );
      expect(parts.first, 'Açıklamayı Dr. Ahmet Yılmaz yaptı.');
    });

    test('parçalar sınırı aşmayacak şekilde birleşir', () {
      final text = List.filled(10, 'Bu bir test cümlesidir.').join(' ');
      final parts = service.splitIntoUtterances(text, maxChars: 60);
      expect(parts.every((p) => p.length <= 60), isTrue);
      expect(parts.join(' '), text);
    });
  });

  group('sanitizeForSpeech', () {
    test('ön sözü, bağlantıyı ve işaretleri temizler; yüzdeyi okutur', () {
      final out = service.sanitizeForSpeech(
        'İşte bugünün brifingi:\n**Merhaba**, ben Pusula. Enflasyon %5,2 '
        'oldu, ayrıntılar https://ornek.com/a adresinde.',
      );
      expect(out.startsWith('Merhaba'), isTrue);
      expect(out, contains('yüzde 5,2'));
      expect(out, isNot(contains('http')));
      expect(out, isNot(contains('**')));
    });
  });

  group('selectArticles', () {
    test('önce gündem, sonra farklı kategoriler; kaynak başına en fazla 2',
        () {
      final trending = [_a('AA', 'gundem'), _a('NTV', 'dunya')];
      final latest = [
        for (var i = 0; i < 6; i++) _a('Investing', 'ekonomi'),
        _a('Sözcü', 'spor'),
        _a('Webtekno', 'teknoloji'),
        _a('BBC', 'dunya'),
      ];
      final picked = DailyBriefingService.selectArticles(
        trending: trending,
        latest: latest,
      );
      expect(picked.take(2), trending);
      expect(picked.where((a) => a.sourceName == 'Investing').length, 2);
      expect(picked.map((a) => a.categoryId),
          containsAll(['spor', 'teknoloji', 'ekonomi']));
      expect(picked.length, 7);
    });
  });

  test('özetsiz haber prompt\'ta "yok" diye işaretlenir', () {
    final prompt = service.buildUserPrompt(
      articles: [_a('AA', 'gundem', title: 'Başlık', summary: '')],
      now: DateTime(2026, 10, 9),
    );
    expect(prompt, contains('Özet: yok'));
  });

  group('briefingSummary', () {
    test('başlığı tekrar eden özetten başlık atılır', () {
      final a = _a('Sabah', 'yasam',
          title: "Esenler'de iki grup arasında çıkan kavgada 2 kişi yaralandı",
          summary: "Esenler'de iki grup arasında çıkan kavgada 2 kişi "
              'yaralandı. Polis şüphelileri arıyor.');
      expect(DailyBriefingService.briefingSummary(a),
          'Polis şüphelileri arıyor.');
    });

    test("RSS'in yarıda kestiği son cümle atılır", () {
      final a = _a('A Spor', 'spor',
          title: 'Torreira kırmızı kart gördü',
          summary: '63. dakikada hakem sarı kart gösterdi. VAR uyarısı '
              'üzerine pozisyonu yeniden inceleyen…');
      expect(DailyBriefingService.briefingSummary(a),
          '63. dakikada hakem sarı kart gösterdi.');
    });

    test('uzun özet cümle sınırından kesilir', () {
      final a = _a('AA', 'gundem',
          title: 'Başlık',
          summary: '${List.filled(12, 'Bu uzun bir haber cümlesidir.').join(' ')} Son');
      final out = DailyBriefingService.briefingSummary(a, maxChars: 120);
      expect(out.length, lessThanOrEqualTo(120));
      expect(out, endsWith('.'));
    });

    test('yalnızca başlıktan ibaret özet "yok" olur', () {
      final a = _a('AA', 'gundem', title: 'Dolar 49 lirayı aştı',
          summary: 'Dolar 49 lirayı aştı');
      expect(DailyBriefingService.briefingSummary(a), 'yok');
    });
  });
}
