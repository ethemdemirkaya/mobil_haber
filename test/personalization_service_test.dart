import 'package:flutter_test/flutter_test.dart';

import 'package:pusula_news/data/local/reading_history_store.dart';
import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/data/repositories/personalization_service.dart';

final _now = DateTime(2026, 10, 9, 12);
var _seq = 0;

Article _a(String category, String source, String title,
    {Duration ago = const Duration(hours: 1)}) {
  _seq++;
  return Article(
    id: 'a$_seq',
    title: title,
    summary: '',
    content: '',
    categoryId: category,
    imageUrl: '',
    author: source,
    publishedAt: _now.subtract(ago),
    readMinutes: 1,
    sourceName: source,
  );
}

HistoryEntry _read(Article a, {Duration ago = const Duration(hours: 2)}) =>
    HistoryEntry(articleId: a.id, readAt: _now.subtract(ago), article: a);

void main() {
  const service = PersonalizationService();

  test('profil zamanla sönümlenir: yeni ilgi eskisini geçer', () {
    final history = [
      // 4 eski ekonomi okuması (~4 hafta önce)
      for (var i = 0; i < 4; i++)
        _read(_a('ekonomi', 'Dünya', 'Borsa günü yükselişle kapattı $i'),
            ago: const Duration(days: 28)),
      // 2 taze spor okuması
      _read(_a('spor', 'NTV Spor', 'Galatasaray derbiyi kazandı')),
      _read(_a('spor', 'NTV Spor', 'Fenerbahçe transfer açıkladı')),
    ];
    final profile = service.buildProfile(history, now: _now);

    expect(profile.categories['spor'], 1.0);
    expect(profile.categories['ekonomi']!, lessThan(0.3));
  });

  test('ilgi alanına uyan haber öne çıkar ve gerekçe taşır', () {
    final history = [
      for (var i = 0; i < 5; i++)
        _read(_a('spor', 'NTV Spor', 'Galatasaray maç sonucu $i')),
    ];
    final profile = service.buildProfile(history, now: _now);
    final candidates = [
      _a('ekonomi', 'Dünya', 'Merkez Bankası faiz kararı'),
      _a('spor', 'Sporx', 'Galatasaray yeni transferini duyurdu'),
      _a('gundem', 'AA', 'Valilikten yağış uyarısı'),
    ];

    final ranked = service.rank(candidates, profile, now: _now);
    expect(ranked.first.article.title, contains('Galatasaray'));
    expect(ranked.first.reason, isNotNull);
  });

  test('okunan haber geriye itilir', () {
    final read = _a('spor', 'NTV Spor', 'Galatasaray kazandı');
    final profile = service.buildProfile([_read(read)], now: _now);
    final other = _a('spor', 'Sporx', 'Galatasaray kazandı, liderliği aldı');

    final ranked =
        service.rank([read, other], profile, readIds: {read.id}, now: _now);
    expect(ranked.first.article.id, other.id);
  });

  test('MMR akışı tek kategoriye kilitlemez', () {
    final history = [
      for (var i = 0; i < 6; i++)
        _read(_a('spor', 'NTV Spor', 'Futbol ligi haftanın maçı $i')),
      _read(_a('teknoloji', 'Webtekno', 'Yapay zeka modeli tanıtıldı')),
    ];
    final profile = service.buildProfile(history, now: _now);
    final candidates = [
      for (var i = 0; i < 8; i++)
        _a('spor', 'NTV Spor', 'Futbol ligi haftanın maçı yeni $i'),
      _a('teknoloji', 'Webtekno', 'Yeni yapay zeka modeli'),
    ];

    final top5 = service
        .rank(candidates, profile, now: _now)
        .take(5)
        .map((r) => r.article.categoryId)
        .toList();
    expect(top5, contains('teknoloji'));
    expect(top5.where((c) => c == 'spor').length, greaterThanOrEqualTo(3));
  });

  test('farklı spor olayları, ilgisiz dolgu haberlerinin önünde kalır', () {
    final history = [
      for (var i = 0; i < 6; i++)
        _read(_a('spor', 'NTV Spor', 'Galatasaray maç sonucu $i')),
    ];
    final profile = service.buildProfile(history, now: _now);
    final candidates = [
      _a('spor', 'NTV Spor', 'Galatasaray Avrupa kupasında tur atladı'),
      _a('spor', 'Sporx', 'Fenerbahçe teknik direktörüyle anlaştı'),
      _a('spor', 'A Spor', 'Milli takımın aday kadrosu açıklandı'),
      _a('gundem', 'AA', 'Valilikten yağış uyarısı'),
      _a('yasam', 'Hürriyet', 'Hafta sonu için gezi önerileri'),
    ];

    final top3 = service
        .rank(candidates, profile, now: _now)
        .take(3)
        .map((r) => r.article.categoryId);
    expect(top3, everyElement('spor'));
  });

  test('soğuk başlangıçta tazelik sırası, gerekçe yok', () {
    final old = _a('spor', 'AA', 'Eski haber', ago: const Duration(hours: 20));
    final fresh =
        _a('ekonomi', 'NTV', 'Taze haber', ago: const Duration(minutes: 5));

    final ranked =
        service.rank([old, fresh], InterestProfile.empty, now: _now);
    expect(ranked.first.article.id, fresh.id);
    expect(ranked.every((r) => r.reason == null), isTrue);
  });
}
