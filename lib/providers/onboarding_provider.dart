import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider() {
    _load();
  }

  bool _initialized = false;
  bool _completed = false;

  bool get initialized => _initialized;
  bool get completed => _completed;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool(AppConstants.prefsOnboardingDone) ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> complete() async {
    if (_completed) return;
    _completed = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsOnboardingDone, true);
  }

  Future<void> reset() async {
    _completed = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefsOnboardingDone);
  }
}
