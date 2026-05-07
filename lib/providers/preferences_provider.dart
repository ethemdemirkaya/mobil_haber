import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/category.dart';
import '../data/models/news_source.dart';

class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider() {
    _load();
  }

  bool _initialized = false;
  bool _breakingNews = true;
  bool _dailyDigest = false;
  final Set<String> _categoryNotifs = <String>{};
  bool _dataSaverImages = false;
  bool _dataSaverAutoplay = true;

  /// Kullanıcının onboarding sırasında (veya ayarlardan) seçtiği kaynaklar.
  /// Boş set + onboarding bitmemişse "henüz seçilmemiş" demektir.
  /// Onboarding tamamlanınca burada en az 1 kaynak olur.
  final Set<String> _selectedSources = <String>{};
  static const _prefsSelectedSources = 'pref_selected_sources';

  /// Geriye dönük uyumluluk: eski sürümde kullanılan "disabled" alanı.
  /// Yeni sürüm whitelist mantığı kullanıyor, ama eski kayıtları okuyup
  /// karşıt olarak çevirebiliyoruz.
  static const _prefsDisabledSourcesLegacy = 'pref_disabled_sources';

  bool get initialized => _initialized;
  bool get breakingNews => _breakingNews;
  bool get dailyDigest => _dailyDigest;
  bool isCategorySubscribed(String id) => _categoryNotifs.contains(id);
  bool get dataSaverImages => _dataSaverImages;
  bool get dataSaverAutoplay => _dataSaverAutoplay;

  /// Kullanıcının seçtiği kaynaklar (whitelist).
  Set<String> get selectedSources => Set.unmodifiable(_selectedSources);
  bool isSourceSelected(String id) => _selectedSources.contains(id);
  int get selectedSourceCount => _selectedSources.length;
  bool get hasAnySelectedSources => _selectedSources.isNotEmpty;

  /// Etkin kaynak listesini katalog sırasıyla döner. Henüz seçim yoksa
  /// (ilk açılış) önerilen kaynakları döner — böylece NewsProvider hiç
  /// boş set ile çalışmaz.
  List<NewsSource> get effectiveSources {
    final ids = _selectedSources.isEmpty
        ? NewsSourceCatalog.recommendedIds.toSet()
        : _selectedSources;
    return NewsSourceCatalog.all
        .where((s) => ids.contains(s.id))
        .toList(growable: false);
  }

  /// Eski API uyumluluğu (LiveNewsScreen vb.). "Bu kaynak gösterilsin mi?"
  /// sorusunu yanıtlar — yeni mimariye whitelist mantığında karşılığı.
  bool isSourceEnabled(String id) => _selectedSources.isEmpty
      ? NewsSourceCatalog.recommendedIds.contains(id)
      : _selectedSources.contains(id);

  /// Eski API: gizlenecek kaynak id'leri (whitelist'in tersi).
  Set<String> get disabledSources {
    final selected = _selectedSources.isEmpty
        ? NewsSourceCatalog.recommendedIds.toSet()
        : _selectedSources;
    return NewsSourceCatalog.all
        .where((s) => !selected.contains(s.id))
        .map((s) => s.id)
        .toSet();
  }

  int get disabledSourceCount => disabledSources.length;

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
    _selectedSources.clear();
    final stored = prefs.getStringList(_prefsSelectedSources);
    if (stored != null) {
      _selectedSources.addAll(stored);
    } else {
      // Migrasyon: eski "disabled" listesi varsa onun tersini whitelist olarak yaz.
      final legacyDisabled =
          prefs.getStringList(_prefsDisabledSourcesLegacy);
      if (legacyDisabled != null) {
        for (final s in NewsSourceCatalog.all) {
          if (!legacyDisabled.contains(s.id)) _selectedSources.add(s.id);
        }
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// Onboarding ve ayarlar ekranı tarafından çağrılır. Kullanıcının seçtiği
  /// kaynak setini tek seferde yazar.
  Future<void> setSelectedSources(Set<String> ids) async {
    _selectedSources
      ..clear()
      ..addAll(ids);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsSelectedSources,
      _selectedSources.toList(),
    );
  }

  /// Tek bir kaynağı seç/seçimden çıkar. UI'da switch ya da chip toggle.
  Future<void> toggleSelectedSource(String sourceId, bool selected) async {
    if (selected) {
      if (!_selectedSources.add(sourceId)) return;
    } else {
      if (!_selectedSources.remove(sourceId)) return;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsSelectedSources,
      _selectedSources.toList(),
    );
  }

  /// Eski API uyumluluğu — `isSourceEnabled`/`toggleSource` çağrılarına
  /// karşılık seçili setin tersine çalışır. UI'da geriye dönük yer hala
  /// olursa otomatik düzgün çalışsın diye köprü.
  Future<void> toggleSource(String sourceId, bool enabled) =>
      toggleSelectedSource(sourceId, enabled);

  Future<void> resetSourcePreferences() async {
    _selectedSources
      ..clear()
      ..addAll(NewsSourceCatalog.recommendedIds);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsSelectedSources,
      _selectedSources.toList(),
    );
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
