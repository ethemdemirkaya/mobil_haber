import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/category.dart';

class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider() {
    _load();
  }

  bool _breakingNews = true;
  bool _dailyDigest = false;
  final Set<String> _categoryNotifs = <String>{};
  bool _dataSaverImages = false;
  bool _dataSaverAutoplay = true;

  /// Live ekranında devre dışı bırakılan kaynak id'leri.
  /// Boş set = tüm available kaynaklar gösterilir.
  final Set<String> _disabledSources = <String>{};
  static const _prefsDisabledSources = 'pref_disabled_sources';

  bool get breakingNews => _breakingNews;
  bool get dailyDigest => _dailyDigest;
  bool isCategorySubscribed(String id) => _categoryNotifs.contains(id);
  bool get dataSaverImages => _dataSaverImages;
  bool get dataSaverAutoplay => _dataSaverAutoplay;

  Set<String> get disabledSources => Set.unmodifiable(_disabledSources);
  bool isSourceEnabled(String id) => !_disabledSources.contains(id);
  int get disabledSourceCount => _disabledSources.length;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _breakingNews =
        prefs.getBool(AppConstants.prefsNotifBreaking) ?? true;
    _dailyDigest = prefs.getBool(AppConstants.prefsNotifDaily) ?? false;
    _dataSaverImages =
        prefs.getBool(AppConstants.prefsDataSaverImages) ?? false;
    _dataSaverAutoplay =
        prefs.getBool(AppConstants.prefsDataSaverAutoplay) ?? true;
    _categoryNotifs.clear();
    for (final c in NewsCategory.values) {
      if (c.id == NewsCategory.all.id) continue;
      final active = prefs.getBool(
              '${AppConstants.prefsNotifCategoryPrefix}${c.id}') ??
          false;
      if (active) _categoryNotifs.add(c.id);
    }
    _disabledSources
      ..clear()
      ..addAll(prefs.getStringList(_prefsDisabledSources) ?? const []);
    notifyListeners();
  }

  Future<void> toggleSource(String sourceId, bool enabled) async {
    if (enabled) {
      if (!_disabledSources.remove(sourceId)) return;
    } else {
      if (!_disabledSources.add(sourceId)) return;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsDisabledSources, _disabledSources.toList());
  }

  Future<void> resetSourcePreferences() async {
    if (_disabledSources.isEmpty) return;
    _disabledSources.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDisabledSources);
  }

  Future<void> setBreakingNews(bool value) async {
    if (_breakingNews == value) return;
    _breakingNews = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsNotifBreaking, value);
  }

  Future<void> setDailyDigest(bool value) async {
    if (_dailyDigest == value) return;
    _dailyDigest = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsNotifDaily, value);
  }

  Future<void> toggleCategory(String id, bool value) async {
    if (value) {
      _categoryNotifs.add(id);
    } else {
      _categoryNotifs.remove(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        '${AppConstants.prefsNotifCategoryPrefix}$id', value);
  }

  Future<void> setDataSaverImages(bool value) async {
    if (_dataSaverImages == value) return;
    _dataSaverImages = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsDataSaverImages, value);
  }

  Future<void> setDataSaverAutoplay(bool value) async {
    if (_dataSaverAutoplay == value) return;
    _dataSaverAutoplay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsDataSaverAutoplay, value);
  }
}
