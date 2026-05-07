import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingMode { normal, sepia }

extension ReadingModeX on ReadingMode {
  String get label => switch (this) {
        ReadingMode.normal => 'Standart',
        ReadingMode.sepia => 'Sepya',
      };
}

enum ListDensity { comfortable, compact }

extension ListDensityX on ListDensity {
  String get label => switch (this) {
        ListDensity.comfortable => 'Rahat',
        ListDensity.compact => 'Sıkışık',
      };
}

class ReadingThemeProvider extends ChangeNotifier {
  ReadingThemeProvider() {
    _load();
  }

  static const _prefsReadingMode = 'pref_reading_mode';
  static const _prefsListDensity = 'pref_list_density';

  ReadingMode _readingMode = ReadingMode.normal;
  ListDensity _density = ListDensity.comfortable;

  ReadingMode get readingMode => _readingMode;
  ListDensity get density => _density;

  bool get isSepia => _readingMode == ReadingMode.sepia;
  bool get isCompact => _density == ListDensity.compact;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_prefsReadingMode);
    final densityIndex = prefs.getInt(_prefsListDensity);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ReadingMode.values.length) {
      _readingMode = ReadingMode.values[modeIndex];
    }
    if (densityIndex != null && densityIndex >= 0 && densityIndex < ListDensity.values.length) {
      _density = ListDensity.values[densityIndex];
    }
    notifyListeners();
  }

  Future<void> setReadingMode(ReadingMode mode) async {
    if (_readingMode == mode) return;
    _readingMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsReadingMode, mode.index);
  }

  Future<void> setDensity(ListDensity density) async {
    if (_density == density) return;
    _density = density;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsListDensity, density.index);
  }

  Future<void> toggleReadingMode() async {
    await setReadingMode(
      _readingMode == ReadingMode.normal ? ReadingMode.sepia : ReadingMode.normal,
    );
  }
}
