import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/article.dart';
import 'local_db.dart';

/// Son başarılı çekimin haberleri — offline açılışta gösterilir.
class CachedFeed {
  const CachedFeed({required this.articles, this.cachedAt});

  final List<Article> articles;
  final DateTime? cachedAt;
}

class ArticleCacheStore {
  const ArticleCacheStore();

  static const String _metaCachedAt = 'news_cached_at';
  static const String _metaSources = 'news_cached_sources';

  /// Önceki cache'i silip [articles] ile değiştirir (tek transaction).
  Future<void> replaceAll(
    List<Article> articles, {
    required List<String> sourceIds,
    DateTime? at,
  }) async {
    final db = await LocalDb.database;
    await db.transaction((txn) async {
      final batch = txn.batch()..delete('articles_cache');
      for (final a in articles) {
        batch.insert(
          'articles_cache',
          {
            'id': a.id,
            'json': jsonEncode(a.toJson()),
            'published_at': a.publishedAt.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      batch
        ..insert(
          'meta',
          {
            'key': _metaCachedAt,
            'value': (at ?? DateTime.now()).toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        )
        ..insert(
          'meta',
          {'key': _metaSources, 'value': sourceIds.join(',')},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      await batch.commit(noResult: true);
    });
  }

  /// Cache'i yayın tarihine göre (yeniden eskiye) okur.
  Future<CachedFeed> read() async {
    final db = await LocalDb.database;
    final rows = await db.query(
      'articles_cache',
      columns: ['json'],
      orderBy: 'published_at DESC',
    );
    final articles = <Article>[];
    for (final r in rows) {
      try {
        final a = Article.tryFromJson(jsonDecode(r['json']! as String));
        if (a != null) articles.add(a);
      } on FormatException {
        // Bozuk satırı atla.
      }
    }
    final meta = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_metaCachedAt],
    );
    final cachedAt = meta.isEmpty
        ? null
        : DateTime.tryParse(meta.first['value']! as String);
    return CachedFeed(articles: articles, cachedAt: cachedAt);
  }

  Future<bool> get isEmpty async {
    final db = await LocalDb.database;
    final n = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM articles_cache'));
    return (n ?? 0) == 0;
  }

  Future<void> clear() async {
    final db = await LocalDb.database;
    await db.transaction((txn) async {
      await txn.delete('articles_cache');
      await txn.delete('meta',
          where: 'key IN (?, ?)', whereArgs: [_metaCachedAt, _metaSources]);
    });
  }
}
