import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pusula_news/data/local/ai_cache_store.dart';
import 'package:pusula_news/data/local/article_cache_store.dart';
import 'package:pusula_news/data/local/local_db.dart';
import 'package:pusula_news/data/local/reading_history_store.dart';
import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/providers/reading_history_provider.dart';

Article _article(String id, {DateTime? at}) => Article(
      id: id,
      title: 'Başlık $id',
      summary: 'Özet',
      content: 'İçerik',
      categoryId: 'gundem',
      imageUrl: '',
      author: 'AA',
      publishedAt: at ?? DateTime(2026, 10, 9),
      readMinutes: 1,
      sourceName: 'AA',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDb.useInMemoryForTests(databaseFactoryFfi);
  });

  test('ArticleCacheStore listeyi değiştirir ve tarih sırasıyla okur', () async {
    const store = ArticleCacheStore();
    await store.replaceAll(
      [_article('eski', at: DateTime(2026, 1, 1)), _article('yeni')],
      sourceIds: const ['aa'],
    );
    await store.replaceAll(
      [_article('a', at: DateTime(2026, 1, 1)), _article('b')],
      sourceIds: const ['aa'],
    );

    final cached = await store.read();
    expect(cached.articles.map((a) => a.id), ['b', 'a']);
    expect(cached.cachedAt, isNotNull);
  });

  test('AiCacheStore kayıt sınırını ve süresini uygular', () async {
    const store = AiCacheStore(maxEntries: 3, ttl: Duration(days: 30));
    final now = DateTime.now();
    await store.put('summary', 'cok-eski', 'x',
        at: now.subtract(const Duration(days: 31)));
    for (var i = 0; i < 5; i++) {
      await store.put('summary', 'k$i', 'v$i',
          at: now.add(Duration(seconds: i)));
    }
    await store.put('bias', 'b', '{}');

    final summaries = await store.load('summary');
    expect(summaries.keys, ['k4', 'k3', 'k2']);
    expect(await store.load('bias'), {'b': '{}'});
  });

  test('ReadingHistoryStore snapshot saklar ve sınırı uygular', () async {
    const store = ReadingHistoryStore(maxEntries: 2);
    final t = DateTime(2026, 10, 9, 12);
    await store.upsert(HistoryEntry(
        articleId: '1', readAt: t, article: _article('1')));
    await store.upsert(HistoryEntry(
        articleId: '2', readAt: t.add(const Duration(minutes: 1))));
    await store.upsert(HistoryEntry(
        articleId: '3',
        readAt: t.add(const Duration(minutes: 2)),
        article: _article('3')));

    final entries = await store.load();
    expect(entries.map((e) => e.articleId), ['3', '2']);
    expect(entries.first.article?.title, 'Başlık 3');
    expect(entries.last.article, isNull);
  });

  test('ReadingHistoryProvider eski id listesini sırasıyla taşır', () async {
    SharedPreferences.setMockInitialValues({
      'pref_reading_history': ['yeni', 'eski'],
    });
    final provider = ReadingHistoryProvider();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(provider.ids, ['yeni', 'eski']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pref_reading_history'), isNull);

    await provider.markRead(_article('eski'));
    expect(provider.ids, ['eski', 'yeni']);
    expect(
      provider.articles().map((a) => a.id),
      ['eski'], // 'yeni' için snapshot yok, lookup verilmedi
    );
  });
}
