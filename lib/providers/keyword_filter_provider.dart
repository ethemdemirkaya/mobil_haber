import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/article.dart';

/// Kullanıcının tanımladığı anahtar kelime filtreleri.
///
/// Bir keyword herhangi bir makalenin başlık/özet/içerik metnine eşleşirse
/// makale "match" olarak işaretlenir; UI bunu rozet olarak gösterir,
/// kişiselleştirilmiş feed bu listeyi bir filtre kriteri olarak kullanır,
/// ileride push notif sistemi (FCM topic veya local) bunu tetikler.
///
/// Anahtar kelime karşılaştırması case-insensitive ve diakritik-duyarsız
/// (Türkçe ı/i, ş/s, ç/c gibi karakter farklarını es geçer).
class KeywordFilterProvider extends ChangeNotifier {
  KeywordFilterProvider() {
    _load();
  }

  static const String _prefsKeywords = 'pref_keyword_filters';
  static const String _prefsNotifyOnMatch = 'pref_keyword_notify_on_match';

  bool _initialized = false;
  final List<String> _keywords = <String>[];
  bool _notifyOnMatch = true;

  bool get initialized => _initialized;
  List<String> get keywords => List.unmodifiable(_keywords);
  bool get hasKeywords => _keywords.isNotEmpty;
  int get count => _keywords.length;
  bool get notifyOnMatch => _notifyOnMatch;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _keywords
      ..clear()
      ..addAll(prefs.getStringList(_prefsKeywords) ?? const []);
    _notifyOnMatch = prefs.getBool(_prefsNotifyOnMatch) ?? true;
    _initialized = true;
    notifyListeners();
  }

  Future<void> add(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return;
    // Case-insensitive duplicate kontrolü.
    final fold = _foldFor(normalized);
    if (_keywords.any((k) => _foldFor(k) == fold)) return;
    _keywords.add(normalized);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeywords, _keywords);
  }

  Future<void> remove(String keyword) async {
    final fold = _foldFor(keyword);
    final before = _keywords.length;
    _keywords.removeWhere((k) => _foldFor(k) == fold);
    if (_keywords.length == before) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeywords, _keywords);
  }

  Future<void> clear() async {
    if (_keywords.isEmpty) return;
    _keywords.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeywords);
  }

  Future<void> setNotifyOnMatch(bool value) async {
    if (_notifyOnMatch == value) return;
    _notifyOnMatch = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsNotifyOnMatch, value);
  }

  /// Verilen makale, kayıtlı keyword'lerden herhangi biriyle eşleşiyor mu?
  bool matchesAny(Article article) =>
      matchedKeywords(article).isNotEmpty;

  /// Makaleye uygulayıp eşleşen keyword listesini döndürür.
  /// UI: rozet'te eşleşen keyword'ü göstermek için.
  List<String> matchedKeywords(Article article) {
    if (_keywords.isEmpty) return const [];
    final blob = _foldFor(
      '${article.title} ${article.summary} ${article.content}',
    );
    final matches = <String>[];
    for (final k in _keywords) {
      if (blob.contains(_foldFor(k))) matches.add(k);
    }
    return matches;
  }

  /// Türkçe karakter farklarını eziyor + lowercase.
  /// Örn: "Galatasaray" ve "galatasaray" eşit; "İstanbul" ⇔ "istanbul".
  static String _foldFor(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g');
  }
}
