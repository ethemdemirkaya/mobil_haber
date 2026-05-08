import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock/mock_news_data.dart';
import '../data/models/article.dart';
import '../data/models/category.dart';
import '../data/models/news_source.dart';
import '../data/repositories/news_cluster_service.dart';
import '../data/repositories/rss_news_service.dart';

/// Pusula — birincil veri kaynağı doğrudan RSS, ikincil olarak offline cache.
///
/// Veri katmanı (öncelik sırası):
///   1. **Live RSS** — `RssNewsService.aggregate()` ile paralel çekim
///   2. **Disk cache** — son başarılı çekim SharedPreferences'a yazılır;
///      offline veya tüm kaynaklar erişilemez olduğunda buradan okunur
///   3. **Mock fallback** — disk cache de yoksa örnek veriler
class NewsProvider extends ChangeNotifier {
  NewsProvider({RssNewsService? rssService})
      : _rss = rssService ?? RssNewsService() {
    // Konstruktörde async'i tetikleyemeyiz ama disk cache'i hızlıca
    // yükleyip gösterirsek splash sırasında bile bir şey görünür.
    _restoreFromCache();
  }

  final RssNewsService _rss;
  final NewsClusterService _clusterer = NewsClusterService();

  bool _loading = true;
  String? _lastError;
  bool _usingFallback = false;
  bool _offline = false;
  DateTime? _lastFetchAt;
  List<Article> _all = const [];
  String _selectedCategoryId = NewsCategory.all.id;

  /// Birden fazla kaynakta görülen ve son saatlerde yayınlanan haberlerin
  /// id seti. ArticleCard "🔥 Gündem" badge göstermek için kullanır.
  /// Cluster servisinden türetilir; her _load() sonrası tazelenir.
  Set<String> _trendingIds = const <String>{};

  /// Her id için kaç kaynakta göründüğü — badge sayısı için (ör. "5×").
  Map<String, int> _trendingSourceCount = const <String, int>{};

  List<NewsSource> _activeSources = const [];
  List<NewsSource> _lastSourceList = const [];

  // ─── Disk cache anahtarları ───
  static const String _prefsCacheData = 'pref_news_cache_articles';
  static const String _prefsCacheAt = 'pref_news_cache_at';
  static const String _prefsCacheSources = 'pref_news_cache_sources';

  // Public getters
  bool get loading => _loading;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;
  bool get usingFallback => _usingFallback;

  /// Çevrimdışı modda mı? (Live çekim başarısız + disk cache'ten geldi)
  bool get offline => _offline;

  /// Mevcut listenin son başarılı çekim zamanı (null = hiç fetch yapılmadı).
  DateTime? get lastFetchAt => _lastFetchAt;

  String get selectedCategoryId => _selectedCategoryId;
  NewsCategory get selectedCategory =>
      NewsCategory.byId(_selectedCategoryId);

  List<NewsSource> get activeSources => _activeSources;
  int get activeSourceCount => _activeSources.length;

  List<Article> get featured {
    if (_all.isEmpty) return const [];
    final byDate = List<Article>.of(_all)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return byDate.take(5).toList(growable: false);
  }

  List<Article> get articles {
    if (_selectedCategoryId == NewsCategory.all.id) {
      return List.unmodifiable(_all);
    }
    return _all
        .where((a) => a.categoryId == _selectedCategoryId)
        .toList(growable: false);
  }

  List<Article> articlesOf(String categoryId) {
    if (categoryId == NewsCategory.all.id) return List.unmodifiable(_all);
    return _all
        .where((a) => a.categoryId == categoryId)
        .toList(growable: false);
  }

  List<Article> latest({int take = 10}) {
    final sorted = List<Article>.of(_all)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted.take(take).toList(growable: false);
  }

  List<Article> trending({int take = 6}) {
    if (_all.isEmpty) return const [];
    final sorted = List<Article>.of(_all)
      ..sort((a, b) {
        final aw = (a.isFeatured ? 1000 : 0);
        final bw = (b.isFeatured ? 1000 : 0);
        final byWeight = (bw - aw);
        if (byWeight != 0) return byWeight;
        return b.publishedAt.compareTo(a.publishedAt);
      });
    return sorted.take(take).toList(growable: false);
  }

  List<Article> related(Article article, {int take = 4}) {
    return _all
        .where((a) =>
            a.id != article.id && a.categoryId == article.categoryId)
        .take(take)
        .toList(growable: false);
  }

  Article? byId(String id) {
    for (final a in _all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Bu makale çoklu-kaynak gündem mi? (≥2 kaynakta yayınlanmış son
  /// 36 saatlik bir küme içinde)
  bool isTrending(String articleId) => _trendingIds.contains(articleId);

  /// Trending kümelenmesinde kaç kaynak yer alıyor (badge sayısı).
  int trendingSourceCount(String articleId) =>
      _trendingSourceCount[articleId] ?? 0;

  /// Trending kümelerini yeniden hesapla. Yüklü makalelere bakar.
  /// _load sonrası ve cache restore sonrası çağrılır.
  void _recomputeTrending() {
    if (_all.length < 4) {
      _trendingIds = const <String>{};
      _trendingSourceCount = const <String, int>{};
      return;
    }
    try {
      final clusters = _clusterer.findClusters(_all);
      final ids = <String>{};
      final counts = <String, int>{};
      for (final c in clusters) {
        // 2+ kaynak → trending. Tüm üye makaleler işaretlenir.
        for (final a in c.articles) {
          ids.add(a.id);
          counts[a.id] = c.sourceCount;
        }
      }
      _trendingIds = ids;
      _trendingSourceCount = counts;
    } catch (e) {
      debugPrint('[Pusula][Trending] cluster hatası: $e');
      _trendingIds = const <String>{};
      _trendingSourceCount = const <String, int>{};
    }
  }

  Future<void> applySources(List<NewsSource> sources) async {
    _lastSourceList = sources;
    await _load();
  }

  Future<void> bootstrapIfNeeded() async {
    if (_lastSourceList.isNotEmpty || _all.isNotEmpty) return;
    _lastSourceList = NewsSourceCatalog.all
        .where((s) => s.recommended)
        .toList(growable: false);
    await _load();
  }

  Future<void> _load() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      if (_lastSourceList.isEmpty) {
        // Disk cache → mock cascade
        final restored = await _readCache();
        if (restored.isNotEmpty) {
          _all = restored;
          _offline = true;
          _usingFallback = false;
        } else {
          _all = await _loadMockFallback();
          _usingFallback = true;
          _offline = false;
        }
        _activeSources = const [];
      } else {
        final fetched = await _rss.aggregate(_lastSourceList, perSource: 8);
        if (fetched.isNotEmpty) {
          _all = fetched;
          _activeSources = _lastSourceList;
          _usingFallback = false;
          _offline = false;
          _lastFetchAt = DateTime.now();
          // Disk cache'i güncelle (await yok — UI bloklanmasın).
          // ignore: unawaited_futures
          _writeCache(fetched, _lastSourceList);
        } else {
          // RSS boş döndü → cache → mock
          await _fallbackToCacheOrMock();
        }
      }
    } catch (e) {
      _lastError = 'Canlı haberler alınamadı: $e';
      await _fallbackToCacheOrMock();
    } finally {
      _recomputeTrending();
      _loading = false;
      notifyListeners();
    }
  }

  /// Live çekim başarısız olduğunda disk cache'e bak; o da yoksa mock'a düş.
  Future<void> _fallbackToCacheOrMock() async {
    final restored = await _readCache();
    if (restored.isNotEmpty) {
      _all = restored;
      _offline = true;
      _usingFallback = false;
    } else {
      _all = await _loadMockFallback();
      _offline = false;
      _usingFallback = true;
    }
  }

  Future<List<Article>> _loadMockFallback() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return MockNewsData.articles;
  }

  // ─── Disk cache (SharedPreferences, JSON serialization) ───
  Future<void> _writeCache(
      List<Article> articles, List<NewsSource> sources) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = articles
          .map((a) => {
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
              })
          .toList(growable: false);
      await prefs.setString(_prefsCacheData, jsonEncode(list));
      await prefs.setString(
        _prefsCacheAt,
        DateTime.now().toIso8601String(),
      );
      await prefs.setStringList(
        _prefsCacheSources,
        sources.map((s) => s.id).toList(),
      );
    } catch (e) {
      debugPrint('[Pusula][NewsCache] yazma hatası: $e');
    }
  }

  Future<List<Article>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsCacheData);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final cachedAt = prefs.getString(_prefsCacheAt);
      if (cachedAt != null) {
        _lastFetchAt = DateTime.tryParse(cachedAt);
      }
      return decoded
          .whereType<Map>()
          .map((m) => Article(
                id: m['id']?.toString() ?? '',
                title: m['title']?.toString() ?? '',
                summary: m['summary']?.toString() ?? '',
                content: m['content']?.toString() ?? '',
                categoryId: m['categoryId']?.toString() ?? 'gundem',
                imageUrl: m['imageUrl']?.toString() ?? '',
                author: m['author']?.toString() ?? 'Anonim',
                publishedAt: DateTime.tryParse(
                        m['publishedAt']?.toString() ?? '') ??
                    DateTime.now(),
                readMinutes: (m['readMinutes'] as num?)?.toInt() ?? 1,
                isFeatured: m['isFeatured'] == true,
                sourceUrl: m['sourceUrl']?.toString() ?? '',
                sourceName: m['sourceName']?.toString() ?? '',
              ))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[Pusula][NewsCache] okuma hatası: $e');
      return const [];
    }
  }

  /// Konstruktör çağrısı sırasında — splash hızla bir şey gösterirken
  /// disk'ten önceki haberi yükle. Live fetch sonra üzerine yazar.
  Future<void> _restoreFromCache() async {
    final cached = await _readCache();
    if (cached.isEmpty) return;
    if (_all.isNotEmpty) return; // live çekim çoktan tamamlandı
    _all = cached;
    _offline = true;
    _loading = false;
    _recomputeTrending();
    notifyListeners();
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsCacheData);
      await prefs.remove(_prefsCacheAt);
      await prefs.remove(_prefsCacheSources);
    } catch (e) {
      debugPrint('[Pusula][NewsCache] temizlik hatası: $e');
    }
  }

  Future<void> refresh() => _load();

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }
}
