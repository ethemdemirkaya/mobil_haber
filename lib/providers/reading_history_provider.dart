import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class ReadingHistoryProvider extends ChangeNotifier {
  ReadingHistoryProvider() {
    _load();
  }

  /// En yeni okunan listenin başında.
  final List<String> _ids = <String>[];

  List<String> get ids => List.unmodifiable(_ids);
  int get count => _ids.length;

  bool wasRead(String articleId) => _ids.contains(articleId);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(AppConstants.prefsReadingHistory) ?? [];
    _ids
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  Future<void> markRead(String articleId) async {
    _ids.removeWhere((e) => e == articleId);
    _ids.insert(0, articleId);
    if (_ids.length > AppConstants.readingHistoryMax) {
      _ids.removeRange(AppConstants.readingHistoryMax, _ids.length);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConstants.prefsReadingHistory, _ids);
  }

  Future<void> remove(String articleId) async {
    if (!_ids.remove(articleId)) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConstants.prefsReadingHistory, _ids);
  }

  Future<void> clear() async {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefsReadingHistory);
  }
}
