import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Article id -> okuma ilerlemesi (0..1, scroll yüzdesi).
///
/// Detay ekranı açıldığında kalınan yere geri dönmek için kullanılır.
/// Kalıcı: SharedPreferences. Değer >= 0.95 ise "okundu" kabul edilebilir.
class ReadingProgressProvider extends ChangeNotifier {
  ReadingProgressProvider() {
    _load();
  }

  static const _prefsKey = 'pref_reading_progress';

  Map<String, double> _progress = const {};

  Map<String, double> get progress => Map.unmodifiable(_progress);

  double get(String articleId) => _progress[articleId] ?? 0.0;

  bool isFinished(String articleId) => get(articleId) >= 0.95;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _progress = decoded.map(
          (k, v) => MapEntry(
            k.toString(),
            (v is num) ? v.toDouble().clamp(0.0, 1.0) : 0.0,
          ),
        );
        notifyListeners();
      }
    } catch (_) {
      // ignore corrupted data
    }
  }

  Future<void> set(String articleId, double value) async {
    final clamped = value.clamp(0.0, 1.0);
    // Çok küçük değişiklikleri ignore et (her scroll event için yazma yapma).
    final current = _progress[articleId] ?? 0.0;
    if ((clamped - current).abs() < 0.02 && clamped < 0.95 && current < 0.95) {
      return;
    }
    _progress = {..._progress, articleId: clamped};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_progress));
  }

  Future<void> clear() async {
    _progress = const {};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
