import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/article.dart';

/// Kaydedilen haberleri yöneten provider.
///
/// **v2 (Mayıs 2026):** Sadece id değil, makalenin tam snapshot'ı
/// (title + url + summary + content + image vs) disk'te saklanır.
/// Böylece:
///   - Haber feed'den çıkmış olsa bile kaydedilen kart açılabilir.
///   - Çevrimdışı modda kayıtlı haberler okunabilir.
///   - Orijinal kaynağa hızlı erişim için URL "tutulur" (kullanıcı tabiri
///     ile beyninde tutulur).
///
/// Backwards-compat: v1'den (sadece id'ler `pref_bookmarks`) yükseltirken
/// id'ler korunur, snapshot'ları bir sonraki feed çekiminde populate
/// edilebilir (id eşleşince provider otomatik kaydeder).
class BookmarkProvider extends ChangeNotifier {
  BookmarkProvider() {
    _load();
  }

  /// id → tam Article snapshot. UI listede gösterirken bunu kullanır.
  /// id sahip olup snapshot'ı eksik olan kayıtlar (v1'den migrate)
  /// `_orphanIds` setinde tutulur.
  final Map<String, Article> _articles = <String, Article>{};
  final Set<String> _orphanIds = <String>{};

  /// Memoized sort sonucu — `_articles` her değiştiğinde geçersiz kılınır.
  /// Liste sık watch edilir (Bookmarks ekranı + ArticleCard); her watch'te
  /// O(n log n) sort yapılmasını engeller.
  List<Article>? _sortedCache;

  static const String _prefsV2 = 'pref_bookmarks_v2';

  Set<String> get ids =>
      Set.unmodifiable({..._articles.keys, ..._orphanIds});
  int get count => _articles.length + _orphanIds.length;

  /// Saved listenin tam Article'ları (en yeni kaydedilen önce).
  List<Article> get savedArticles {
    final cached = _sortedCache;
    if (cached != null) return cached;
    final list = _articles.values.toList(growable: false);
    list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    _sortedCache = list;
    return list;
  }

  void _invalidateSortedCache() => _sortedCache = null;

  bool isBookmarked(String articleId) =>
      _articles.containsKey(articleId) || _orphanIds.contains(articleId);

  /// Kayıtlı makalenin tam snapshot'ını ver. Null = sadece id var (v1
  /// migration), feed'de yok demektir.
  Article? snapshotOf(String articleId) => _articles[articleId];

  /// Article URL'i (sourceUrl) — bookmark linkinin "beyinde tutulması".
  /// Kaydedilen anki URL kalıcıdır; feed sonradan değişse bile.
  String? urlOf(String articleId) {
    final s = _articles[articleId];
    if (s == null) return null;
    return s.sourceUrl.isEmpty ? null : s.sourceUrl;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // v2: snapshot listesi (JSON)
    final raw = prefs.getString(_prefsV2);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final m in decoded) {
            if (m is Map) {
              final a = _articleFromJson(m.cast<String, dynamic>());
              if (a != null) _articles[a.id] = a;
            }
          }
        }
      } catch (e) {
        debugPrint('[Pusula][Bookmark] v2 cache okuma hatası: $e');
      }
    }
    // v1 migration: eski sürümden gelen id-only liste; snapshot'ı yok.
    final legacy = prefs.getStringList(AppConstants.prefsBookmarks);
    if (legacy != null) {
      for (final id in legacy) {
        if (!_articles.containsKey(id)) _orphanIds.add(id);
      }
    }
    _invalidateSortedCache();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _articles.values
        .map(_articleToJson)
        .toList(growable: false);
    await prefs.setString(_prefsV2, jsonEncode(list));
    // v1 anahtarını da güncel tut (migration backward-compat).
    await prefs.setStringList(
      AppConstants.prefsBookmarks,
      ids.toList(),
    );
  }

  /// Article snapshot'ı ile kaydet/kaldır toggle.
  Future<void> toggleArticle(Article article) async {
    if (isBookmarked(article.id)) {
      _articles.remove(article.id);
      _orphanIds.remove(article.id);
    } else {
      _articles[article.id] = article;
      _orphanIds.remove(article.id);
    }
    _invalidateSortedCache();
    notifyListeners();
    await _persist();
  }

  /// Geriye dönük uyumluluk: id-only çağrılar (article elimizde yokken).
  /// Eğer id zaten _articles'ta varsa snapshot'ı korur; yoksa orphan
  /// olarak ekler/kaldırır.
  Future<void> toggle(String articleId) async {
    if (_articles.containsKey(articleId)) {
      _articles.remove(articleId);
    } else if (_orphanIds.contains(articleId)) {
      _orphanIds.remove(articleId);
    } else {
      _orphanIds.add(articleId);
    }
    _invalidateSortedCache();
    notifyListeners();
    await _persist();
  }

  /// Eğer feed'de gördüğümüz bir orphan id'nin snapshot'ı geldiyse
  /// otomatik upgrade et (v1 migration için kullanışlı).
  Future<void> upgradeFromFeed(Iterable<Article> feedArticles) async {
    if (_orphanIds.isEmpty) return;
    var changed = false;
    for (final a in feedArticles) {
      if (_orphanIds.remove(a.id)) {
        _articles[a.id] = a;
        changed = true;
      }
    }
    if (changed) {
      _invalidateSortedCache();
      notifyListeners();
      await _persist();
    }
  }

  Future<void> remove(String articleId) async {
    final removedFromArticles = _articles.remove(articleId) != null;
    final removedFromOrphans = _orphanIds.remove(articleId);
    if (!removedFromArticles && !removedFromOrphans) return;
    _invalidateSortedCache();
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    if (_articles.isEmpty && _orphanIds.isEmpty) return;
    _articles.clear();
    _orphanIds.clear();
    _invalidateSortedCache();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsV2);
    await prefs.remove(AppConstants.prefsBookmarks);
  }

  // ─── JSON serialization ───
  Map<String, dynamic> _articleToJson(Article a) => {
        'id': a.id,
        'title': a.title,
        'summary': a.summary,
        'content': a.content,
        'categoryId': a.categoryId,
        'imageUrl': a.imageUrl,
        'author': a.author,
        'publishedAt': a.publishedAt.toIso8601String(),
        'readMinutes': a.readMinutes,
        'isFeatured': a.isFeatured,
        'sourceUrl': a.sourceUrl,
        'sourceName': a.sourceName,
      };

  Article? _articleFromJson(Map<String, dynamic> m) {
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return Article(
      id: id,
      title: m['title']?.toString() ?? '',
      summary: m['summary']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      categoryId: m['categoryId']?.toString() ?? 'gundem',
      imageUrl: m['imageUrl']?.toString() ?? '',
      author: m['author']?.toString() ?? 'Anonim',
      publishedAt:
          DateTime.tryParse(m['publishedAt']?.toString() ?? '') ??
              DateTime.now(),
      readMinutes: (m['readMinutes'] as num?)?.toInt() ?? 1,
      isFeatured: m['isFeatured'] == true,
      sourceUrl: m['sourceUrl']?.toString() ?? '',
      sourceName: m['sourceName']?.toString() ?? '',
    );
  }
}
