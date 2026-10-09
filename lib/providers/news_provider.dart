import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/article_cache_store.dart';
import '../data/models/article.dart';
import '../data/models/category.dart';
import '../data/models/news_source.dart';
import '../data/repositories/news_cluster_service.dart';
import '../data/repositories/rss_news_service.dart';
import '../data/sources/news_aggregator.dart';

/// Pusula — birincil veri kaynağı doğrudan RSS, ikincil olarak offline cache.
///
/// Veri katmanı (öncelik sırası):
///   1. **Canlı çekim** — `NewsAggregator.aggregate()`: kaynak başına plan
///      (yayıncı API'si, o olmazsa RSS) paralel çalışır
///   2. **Disk cache** — son başarılı çekim SQLite'a yazılır;
///      offline veya tüm kaynaklar erişilemez olduğunda buradan okunur
///
/// Disk cache de yoksa liste boş kalır ve [unavailable] true olur — haber
/// uygulamasında örnek/uydurma veri göstermek kullanıcıyı yanıltır.
class NewsProvider extends ChangeNotifier {
  NewsProvider({
    RssNewsService? rssService,
    ArticleCacheStore cacheStore = const ArticleCacheStore(),
  })  : _aggregator = NewsAggregator(rss: rssService ?? RssNewsService()),
        _cacheStore = cacheStore {
    // Konstruktörde async'i tetikleyemeyiz ama disk cache'i hızlıca
    // yükleyip gösterirsek splash sırasında bile bir şey görünür.
    _restoreFromCache();
  }

  final NewsAggregator _aggregator;
  final ArticleCacheStore _cacheStore;
  final NewsClusterService _clusterer = const NewsClusterService();

  bool _loading = true;
  String? _lastError;
  bool _unavailable = false;
  bool _offline = false;

  /// Devam eden çekim — aynı kaynak listesiyle gelen ikinci çağrı (splash +
  /// MainNavigation, art arda pull-to-refresh) yeni istek atmak yerine
  /// bunu bekler.
  Future<void>? _inflight;
  String? _inflightKey;

  /// Çekim sürerken farklı bir kaynak listesi geldiyse, mevcut çekim
  /// bitince bir kez daha yüklenir.
  bool _reloadQueued = false;
  DateTime? _lastFetchAt;
  List<Article> _all = const [];
  String _selectedCategoryId = NewsCategory.all.id;

  /// Çapraz kaynak kümeleri — her liste değişiminde bir kez (gerekirse
  /// ayrı isolate'te) hesaplanır; ekranlar build içinde yeniden hesaplamaz.
  List<NewsCluster> _clusters = const [];

  /// Gündem kümeleri ([_minHotScore] üstü, en fazla [_maxTrending]),
  /// skora göre sıralı.
  List<NewsCluster> _trendingClusters = const [];

  /// Gündem kümelerindeki her haber id'si → kümedeki kaynak sayısı.
  /// ArticleCard "🔥 N kaynak" rozeti için.
  Map<String, int> _trendingSourceCount = const <String, int>{};

  /// Eski bir küme hesabının yenisinin üzerine yazmasını önler.
  int _clusterGeneration = 0;

  /// ≈ 2 kaynak az önce ya da 3 kaynak ~6 saat önce yayınladı.
  static const double _minHotScore = 1.5;
  static const int _maxTrending = 10;

  List<NewsSource> _activeSources = const [];
  List<NewsSource> _lastSourceList = const [];

  // ─── Eski (SharedPreferences) cache anahtarları — tek seferlik taşıma ───
  static const String _legacyPrefsData = 'pref_news_cache_articles';
  static const String _legacyPrefsAt = 'pref_news_cache_at';
  static const String _legacyPrefsSources = 'pref_news_cache_sources';

  // Public getters
  bool get loading => _loading;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;

  /// Canlı çekim başarısız ve disk cache de boş — gösterilecek haber yok.
  bool get unavailable => _unavailable;

  /// Kaynak listesi en az bir kez uygulandı mı? (Çekim sürüyor olsa bile.)
  /// MainNavigation'ın splash'ın başlattığı çekimi tekrar tetiklememesi için.
  bool get hasRequestedSources => _lastSourceList.isNotEmpty;

  /// Çevrimdışı modda mı? (Live çekim başarısız + disk cache'ten geldi)
  bool get offline => _offline;

  /// Mevcut listenin son başarılı çekim zamanı (null = hiç fetch yapılmadı).
  DateTime? get lastFetchAt => _lastFetchAt;

  String get selectedCategoryId => _selectedCategoryId;
  NewsCategory get selectedCategory =>
      NewsCategory.byId(_selectedCategoryId);

  List<NewsSource> get activeSources => _activeSources;
  int get activeSourceCount => _activeSources.length;

  /// Manşet carousel'i — kümelerle birlikte bir kez hesaplanır
  /// (bkz. [_pickFeatured]).
  List<Article> get featured => _featured;
  List<Article> _featured = const [];

  /// Ana sayfadaki "Son haberler" listesi. "Tümü" seçiliyken manşette ve
  /// Gündem kartlarında zaten gösterilen haberler tekrar edilmez; aynı
  /// haber üç bölümde birden görünüyordu.
  List<Article> get homeFeed {
    if (_selectedCategoryId != NewsCategory.all.id) return articles;
    final shown = {
      for (final a in _featured) a.id,
      for (final c in _trendingClusters) c.articles.first.id,
    };
    return _all.where((a) => !shown.contains(a.id)).toList(growable: false);
  }

  /// Gündem kümelerine girmeyen, görseli olan, her biri farklı kaynaktan en
  /// yeni haberler; görselli haber azsa görselsizlerle tamamlanır.
  List<Article> _pickFeatured({int take = 5}) {
    final inTrending = {
      for (final c in _trendingClusters)
        for (final a in c.articles) a.id,
    };
    final byDate = _all.where((a) => !inTrending.contains(a.id)).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final picked = <Article>[];
    final sources = <String>{};
    for (final withImage in [true, false]) {
      for (final a in byDate) {
        if (picked.length >= take) break;
        if (a.imageUrl.isNotEmpty != withImage) continue;
        if (!sources.add(a.sourceName.isEmpty ? a.id : a.sourceName)) {
          continue;
        }
        picked.add(a);
      }
    }
    return List.unmodifiable(picked);
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

  /// Gündemdeki olaylar — her gündem kümesinden en yeni haber, gündem
  /// skoruna göre sıralı. Çoklu kaynak yoksa boş döner.
  List<Article> trending({int take = 6}) => _trendingClusters
      .take(take)
      .map((c) => c.articles.first)
      .toList(growable: false);

  /// Çapraz bakış kümeleri (≥2 bağımsız kaynak), gündem skoruna göre sıralı.
  List<NewsCluster> get clusters => _clusters;

  /// İçerikçe benzer haberler. Benzer bulunamazsa boş döner ve detay
  /// ekranı bölümü gizler — aynı kategoriyle "doldurmak" alakasız haber
  /// gösteriyordu. Liste değişene kadar haber başına önbellekli (detay
  /// ekranı her yeniden çizimde sorar).
  List<Article> related(Article article, {int take = 4}) {
    final cached = _relatedCache[article.id];
    if (cached != null) return cached;
    final result = List<Article>.unmodifiable(
        _clusterer.mostSimilar(article, _all, take: take));
    _relatedCache[article.id] = result;
    return result;
  }

  final Map<String, List<Article>> _relatedCache = <String, List<Article>>{};

  Article? byId(String id) {
    for (final a in _all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Bu makale gündemdeki (çok kaynaklı ve taze) bir olayın parçası mı?
  bool isTrending(String articleId) =>
      _trendingSourceCount.containsKey(articleId);

  /// Trending kümesinde kaç kaynak yer alıyor (badge sayısı).
  int trendingSourceCount(String articleId) =>
      _trendingSourceCount[articleId] ?? 0;

  /// Kümeleri ve gündemi yeniden hesapla. _load sonrası ve cache restore
  /// sonrası çağrılır; büyük listelerde hesap ayrı isolate'te yapılır.
  Future<void> _recomputeClusters() async {
    _relatedCache.clear();
    final generation = ++_clusterGeneration;
    final snapshot = _all;
    List<NewsCluster> clusters = const [];
    if (snapshot.length >= 4) {
      try {
        clusters = await _clusterer.findClustersAsync(snapshot);
      } catch (e) {
        debugPrint('[Pusula][Cluster] hesaplama hatası: $e');
      }
    }
    if (generation != _clusterGeneration) return;
    final trending = clusters
        .where((c) => c.hotScore >= _minHotScore)
        .take(_maxTrending)
        .toList(growable: false);
    final counts = <String, int>{};
    for (final c in trending) {
      for (final a in c.articles) {
        counts[a.id] = c.sourceCount;
      }
    }
    _clusters = clusters;
    _trendingClusters = trending;
    _trendingSourceCount = counts;
    _featured = _pickFeatured();
  }

  Future<void> applySources(List<NewsSource> sources) {
    _lastSourceList = sources;
    return _load();
  }

  Future<void> bootstrapIfNeeded() async {
    if (_lastSourceList.isNotEmpty || _all.isNotEmpty) return;
    _lastSourceList = NewsSourceCatalog.all
        .where((s) => s.recommended)
        .toList(growable: false);
    await _load();
  }

  String _sourcesKey(List<NewsSource> sources) =>
      sources.map((s) => s.id).join(',');

  Future<void> _load() {
    final key = _sourcesKey(_lastSourceList);
    final inflight = _inflight;
    if (inflight != null) {
      if (key != _inflightKey) _reloadQueued = true;
      return inflight;
    }
    _inflightKey = key;
    final future = _doLoad().whenComplete(() {
      _inflight = null;
      _inflightKey = null;
      if (_reloadQueued) {
        _reloadQueued = false;
        // ignore: unawaited_futures
        _load();
      }
    });
    _inflight = future;
    return future;
  }

  Future<void> _doLoad() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    final sources = _lastSourceList;
    try {
      if (sources.isEmpty) {
        await _fallbackToCache();
        _activeSources = const [];
      } else {
        final fetched = await _aggregator.aggregate(sources, perSource: 8);
        if (fetched.isNotEmpty) {
          _all = fetched;
          _activeSources = sources;
          _unavailable = false;
          _offline = false;
          _lastFetchAt = DateTime.now();
          // Disk cache'i güncelle (await yok — UI bloklanmasın).
          // ignore: unawaited_futures
          _writeCache(fetched, sources);
        } else {
          await _fallbackToCache();
        }
      }
    } catch (e) {
      _lastError = 'Canlı haberler alınamadı: $e';
      await _fallbackToCache();
    } finally {
      await _recomputeClusters();
      _loading = false;
      notifyListeners();
    }
  }

  /// Live çekim başarısız olduğunda disk cache'e bak. O da yoksa ekranda
  /// zaten bir liste varsa (önceki başarılı çekim) onu koru; hiç yoksa
  /// [unavailable] durumuna geç.
  Future<void> _fallbackToCache() async {
    final restored = await _readCache();
    if (restored.isNotEmpty) {
      _all = restored;
      _offline = true;
      _unavailable = false;
    } else if (_all.isNotEmpty) {
      _offline = true;
      _unavailable = false;
    } else {
      _offline = false;
      _unavailable = true;
    }
  }

  // ─── Disk cache (SQLite) ───
  Future<void> _writeCache(
      List<Article> articles, List<NewsSource> sources) async {
    try {
      await _cacheStore.replaceAll(
        articles,
        sourceIds: sources.map((s) => s.id).toList(growable: false),
      );
    } catch (e) {
      debugPrint('[Pusula][NewsCache] yazma hatası: $e');
    }
  }

  Future<List<Article>> _readCache() async {
    try {
      await _migrateLegacyCache();
      final cached = await _cacheStore.read();
      if (cached.cachedAt != null) _lastFetchAt = cached.cachedAt;
      return cached.articles;
    } catch (e) {
      debugPrint('[Pusula][NewsCache] okuma hatası: $e');
      return const [];
    }
  }

  bool _legacyChecked = false;

  /// Eski sürüm haber cache'ini SharedPreferences'tan SQLite'a bir kez
  /// taşır ve eski anahtarları siler.
  Future<void> _migrateLegacyCache() async {
    if (_legacyChecked) return;
    _legacyChecked = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyPrefsData);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && await _cacheStore.isEmpty) {
        final articles =
            decoded.map(Article.tryFromJson).whereType<Article>().toList();
        await _cacheStore.replaceAll(
          articles,
          sourceIds: prefs.getStringList(_legacyPrefsSources) ?? const [],
          at: DateTime.tryParse(prefs.getString(_legacyPrefsAt) ?? ''),
        );
      }
    } catch (e) {
      debugPrint('[Pusula][NewsCache] eski cache taşınamadı: $e');
    }
    await prefs.remove(_legacyPrefsData);
    await prefs.remove(_legacyPrefsAt);
    await prefs.remove(_legacyPrefsSources);
  }

  /// Konstruktör çağrısı sırasında — splash hızla bir şey gösterirken
  /// disk'ten önceki haberi yükle. Live fetch sonra üzerine yazar.
  Future<void> _restoreFromCache() async {
    final cached = await _readCache();
    if (cached.isEmpty) return;
    if (_all.isNotEmpty) return; // live çekim çoktan tamamlandı
    _all = cached;
    _offline = true;
    _unavailable = false;
    // Çekim hâlâ sürüyorsa loading'i kapatma — banner'lar ve
    // pull-to-refresh durumu doğru kalsın.
    if (_inflight == null) _loading = false;
    notifyListeners();
    await _recomputeClusters();
    notifyListeners();
  }

  Future<void> clearCache() async {
    try {
      await _cacheStore.clear();
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
