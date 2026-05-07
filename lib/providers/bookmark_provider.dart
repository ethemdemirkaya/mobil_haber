import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class BookmarkProvider extends ChangeNotifier {
  BookmarkProvider() {
    _load();
  }

  final Set<String> _ids = <String>{};

  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  bool isBookmarked(String articleId) => _ids.contains(articleId);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(AppConstants.prefsBookmarks) ?? [];
    _ids
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  Future<void> toggle(String articleId) async {
    if (_ids.contains(articleId)) {
      _ids.remove(articleId);
    } else {
      _ids.add(articleId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      AppConstants.prefsBookmarks,
      _ids.toList(),
    );
  }

  Future<void> remove(String articleId) async {
    if (!_ids.remove(articleId)) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      AppConstants.prefsBookmarks,
      _ids.toList(),
    );
  }

  Future<void> clearAll() async {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefsBookmarks);
  }
}
