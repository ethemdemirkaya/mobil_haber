import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/article.dart';
import 'local_db.dart';

/// Okuma geçmişinde bir kayıt. [article] eski sürümden taşınan kayıtlarda
/// (yalnızca id saklanıyordu) null olabilir.
class HistoryEntry {
  const HistoryEntry({
    required this.articleId,
    required this.readAt,
    this.article,
  });

  final String articleId;
  final DateTime readAt;
  final Article? article;
}

class ReadingHistoryStore {
  const ReadingHistoryStore({this.maxEntries = 500});

  final int maxEntries;

  /// En yeni okunan en başta.
  Future<List<HistoryEntry>> load() async {
    final db = await LocalDb.database;
    final rows = await db.query(
      'reading_history',
      orderBy: 'read_at DESC',
      limit: maxEntries,
    );
    return rows.map((r) {
      Article? article;
      final json = r['json'] as String?;
      if (json != null) {
        try {
          article = Article.tryFromJson(jsonDecode(json));
        } on FormatException {
          article = null;
        }
      }
      return HistoryEntry(
        articleId: r['article_id']! as String,
        readAt: DateTime.fromMillisecondsSinceEpoch(r['read_at']! as int),
        article: article,
      );
    }).toList(growable: false);
  }

  Future<void> upsert(HistoryEntry entry) => upsertAll([entry]);

  Future<void> upsertAll(List<HistoryEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await LocalDb.database;
    final batch = db.batch();
    for (final e in entries) {
      batch.insert(
        'reading_history',
        {
          'article_id': e.articleId,
          'json': e.article == null ? null : jsonEncode(e.article!.toJson()),
          'read_at': e.readAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await db.rawDelete('''
      DELETE FROM reading_history WHERE article_id NOT IN (
        SELECT article_id FROM reading_history
        ORDER BY read_at DESC LIMIT ?
      )''', [maxEntries]);
  }

  Future<void> remove(String articleId) async {
    final db = await LocalDb.database;
    await db.delete('reading_history',
        where: 'article_id = ?', whereArgs: [articleId]);
  }

  Future<void> clear() async {
    final db = await LocalDb.database;
    await db.delete('reading_history');
  }
}
