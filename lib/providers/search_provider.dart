import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider() {
    _loadHistory();
  }

  String _query = '';
  final List<String> _history = [];

  String get query => _query;
  List<String> get history => List.unmodifiable(_history);

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  Future<void> commit(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _history.removeWhere(
        (e) => e.toLowerCase() == trimmed.toLowerCase());
    _history.insert(0, trimmed);
    if (_history.length > AppConstants.searchHistoryMax) {
      _history.removeRange(AppConstants.searchHistoryMax, _history.length);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        AppConstants.prefsSearchHistory, _history);
  }

  Future<void> removeFromHistory(String value) async {
    if (!_history.remove(value)) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        AppConstants.prefsSearchHistory, _history);
  }

  Future<void> clearHistory() async {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefsSearchHistory);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getStringList(AppConstants.prefsSearchHistory) ?? [];
    _history
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }
}
