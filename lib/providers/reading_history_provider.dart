import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/local/reading_history_store.dart';
import '../data/models/article.dart';

/// Okuma geçmişi — her kayıt okunan haberin snapshot'ını ve okunma zamanını
/// taşır. Eskiden yalnızca id saklanıyordu; haber akıştan düşünce geçmiş
/// ekranında kayboluyordu.
class ReadingHistoryProvider extends ChangeNotifier {
  ReadingHistoryProvider({
    ReadingHistoryStore store = const ReadingHistoryStore(
      maxEntries: AppConstants.readingHistoryMax,
    ),
  }) : _store = store {
    _load();
  }

  final ReadingHistoryStore _store;

  /// En yeni okunan listenin başında.
  final List<HistoryEntry> _entries = <HistoryEntry>[];
  final Set<String> _idSet = <String>{};

  List<HistoryEntry> get entries => List.unmodifiable(_entries);
  List<String> get ids =>
      _entries.map((e) => e.articleId).toList(growable: false);
  int get count => _entries.length;

  bool wasRead(String articleId) => _idSet.contains(articleId);

  /// Geçmişteki haberler; snapshot'ı olmayan eski kayıtlar [lookup] ile
  /// (genelde `NewsProvider.byId`) çözülür, bulunamazsa atlanır.
  List<Article> articles({Article? Function(String id)? lookup}) => _entries
      .map((e) => e.article ?? lookup?.call(e.articleId))
      .whereType<Article>()
      .toList(growable: false);

  Future<void> _load() async {
    try {
      await _migrateLegacy();
      final loaded = await _store.load();
      _entries
        ..clear()
        ..addAll(loaded);
      _idSet
        ..clear()
        ..addAll(loaded.map((e) => e.articleId));
      notifyListeners();
    } catch (e) {
      debugPrint('[Pusula][History] yükleme hatası: $e');
    }
  }

  /// Eski sürümün id listesini (SharedPreferences) tabloya bir kez taşır.
  /// Sıra korunur: listenin başı en yeni.
  Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(AppConstants.prefsReadingHistory);
    if (legacy == null) return;
    final now = DateTime.now();
    await _store.upsertAll([
      for (var i = 0; i < legacy.length; i++)
        HistoryEntry(
          articleId: legacy[i],
          readAt: now.subtract(Duration(seconds: i)),
        ),
    ]);
    await prefs.remove(AppConstants.prefsReadingHistory);
  }

  Future<void> markRead(Article article) async {
    final entry = HistoryEntry(
      articleId: article.id,
      readAt: DateTime.now(),
      article: article,
    );
    _entries
      ..removeWhere((e) => e.articleId == article.id)
      ..insert(0, entry);
    _idSet.add(article.id);
    if (_entries.length > AppConstants.readingHistoryMax) {
      for (final e in _entries.sublist(AppConstants.readingHistoryMax)) {
        _idSet.remove(e.articleId);
      }
      _entries.removeRange(AppConstants.readingHistoryMax, _entries.length);
    }
    notifyListeners();
    try {
      await _store.upsert(entry);
    } catch (e) {
      debugPrint('[Pusula][History] yazma hatası: $e');
    }
  }

  Future<void> remove(String articleId) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.articleId == articleId);
    if (_entries.length == before) return;
    _idSet.remove(articleId);
    notifyListeners();
    await _store.remove(articleId);
  }

  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries.clear();
    _idSet.clear();
    notifyListeners();
    await _store.clear();
  }
}
