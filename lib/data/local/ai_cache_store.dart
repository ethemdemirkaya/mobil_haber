import 'package:sqflite/sqflite.dart';

import 'local_db.dart';

/// AI sonuçları (özet, yönlülük raporu) için boyut ve süre sınırlı cache.
///
/// Eskiden SharedPreferences'ta tek JSON olarak tutuluyor, hiç silinmeden
/// büyüyordu ve her yeni sonuçta tamamı yeniden yazılıyordu. Burada her
/// kayıt tek satır; [maxEntries] aşılınca ve [ttl] dolunca en eskiler
/// silinir.
class AiCacheStore {
  const AiCacheStore({
    this.maxEntries = 300,
    this.ttl = const Duration(days: 30),
  });

  /// Tür başına (özet, bias…) en fazla kayıt sayısı.
  final int maxEntries;

  /// Bu süreden eski kayıtlar silinir — haberler eskir, model değişir.
  final Duration ttl;

  static const String kindSummary = 'summary';
  static const String kindBias = 'bias';

  /// [kind] türündeki geçerli kayıtları en yeniden eskiye yükler.
  Future<Map<String, String>> load(String kind) async {
    final db = await LocalDb.database;
    await _prune(db, kind);
    final rows = await db.query(
      'ai_cache',
      columns: ['key', 'value'],
      where: 'kind = ?',
      whereArgs: [kind],
      orderBy: 'created_at DESC',
    );
    return {
      for (final r in rows) r['key']! as String: r['value']! as String,
    };
  }

  Future<void> put(String kind, String key, String value, {DateTime? at}) =>
      putAll(kind, {key: value}, at: at);

  Future<void> putAll(
    String kind,
    Map<String, String> entries, {
    DateTime? at,
  }) async {
    if (entries.isEmpty) return;
    final db = await LocalDb.database;
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final batch = db.batch();
    entries.forEach((key, value) {
      batch.insert(
        'ai_cache',
        {'kind': kind, 'key': key, 'value': value, 'created_at': ts},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
    await _prune(db, kind);
  }

  Future<void> remove(String kind, String key) async {
    final db = await LocalDb.database;
    await db.delete('ai_cache',
        where: 'kind = ? AND key = ?', whereArgs: [kind, key]);
  }

  Future<void> clear(String kind) async {
    final db = await LocalDb.database;
    await db.delete('ai_cache', where: 'kind = ?', whereArgs: [kind]);
  }

  Future<void> _prune(Database db, String kind) async {
    final cutoff = DateTime.now().subtract(ttl).millisecondsSinceEpoch;
    await db.delete('ai_cache',
        where: 'kind = ? AND created_at < ?', whereArgs: [kind, cutoff]);
    await db.rawDelete('''
      DELETE FROM ai_cache WHERE kind = ? AND key NOT IN (
        SELECT key FROM ai_cache WHERE kind = ?
        ORDER BY created_at DESC LIMIT ?
      )''', [kind, kind, maxEntries]);
  }
}
