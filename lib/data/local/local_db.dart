import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Uygulamanın yerel SQLite veritabanı.
///
/// SharedPreferences küçük ayarlar için tasarlanmıştır; haber listesini
/// tam içerikle tek bir JSON string olarak yazmak her yenilemede tüm
/// listeyi yeniden serileştiriyor, AI cache'leri ise sınırsız büyüyordu.
///
/// Tablolar:
///   - `articles_cache` — son başarılı çekimin haberleri (offline okuma).
///   - `ai_cache`       — özet / yönlülük sonuçları; boyut ve süre sınırlı.
///   - `reading_history`— okunan haberin snapshot'ı; haber akıştan düşse de
///                        geçmişte görünür, kişiselleştirme için sinyal.
///   - `meta`           — küçük anahtar/değer kayıtları (cache zamanı vb.).
class LocalDb {
  LocalDb._();

  static const String _fileName = 'pusula.db';
  static const int _version = 1;

  static Future<Database>? _db;
  static DatabaseFactory? _factoryOverride;
  static String? _pathOverride;

  /// Paylaşılan bağlantı; ilk çağrıda açılır.
  static Future<Database> get database => _db ??= _open();

  /// Testlerde in-memory veritabanı kullanmak için. Her çağrı temiz bir
  /// veritabanıyla başlar.
  @visibleForTesting
  static Future<void> useInMemoryForTests(DatabaseFactory factory) async {
    final current = _db;
    _db = null;
    if (current != null) await (await current).close();
    _factoryOverride = factory;
    _pathOverride = inMemoryDatabasePath;
  }

  static Future<Database> _open() async {
    final factory = _factoryOverride ?? databaseFactory;
    final path =
        _pathOverride ?? p.join(await factory.getDatabasesPath(), _fileName);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: (db, version) => _createV1(db),
        singleInstance: _pathOverride == null,
      ),
    );
  }

  static Future<void> _createV1(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE articles_cache (
          id TEXT PRIMARY KEY,
          json TEXT NOT NULL,
          published_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE ai_cache (
          kind TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (kind, key)
        )''')
      ..execute(
          'CREATE INDEX ai_cache_kind_created ON ai_cache (kind, created_at)')
      ..execute('''
        CREATE TABLE reading_history (
          article_id TEXT PRIMARY KEY,
          json TEXT,
          read_at INTEGER NOT NULL
        )''')
      ..execute('CREATE INDEX reading_history_read_at '
          'ON reading_history (read_at)')
      ..execute('''
        CREATE TABLE meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )''');
    await batch.commit(noResult: true);
  }
}
