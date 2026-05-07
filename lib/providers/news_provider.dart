import 'package:flutter/foundation.dart';

import '../data/mock/mock_news_data.dart';
import '../data/models/article.dart';
import '../data/models/category.dart';
import '../data/models/news_source.dart';
import '../data/repositories/rss_news_service.dart';

/// **mobil_haber özetleyici** — birincil veri kaynağı doğrudan RSS.
///
/// Backend gerektirmez. Kullanıcının seçtiği `NewsSource` listesinden
/// `RssNewsService.aggregate()` ile haberleri paralel çekip birleştirir.
/// Hiç haber gelmezse mock'a düşer (offline / tüm feed'ler erişilemez).
class NewsProvider extends ChangeNotifier {
  NewsProvider({RssNewsService? rssService})
      : _rss = rssService ?? RssNewsService();

  final RssNewsService _rss;

  bool _loading = true;
  String? _lastError;
  bool _usingFallback = false;
  List<Article> _all = const [];
  String _selectedCategoryId = NewsCategory.all.id;

  /// Aktif çekim sırasında kullanılan kaynak id'leri. UI bu seti chip
  /// olarak gösterip altında "kaç kaynak" bilgisi verir.
  List<NewsSource> _activeSources = const [];

  /// Aktif kaynak listesini set eden son komut (refresh sırasında kullanırız).
  List<NewsSource> _lastSourceList = const [];

  bool get loading => _loading;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;
  bool get usingFallback => _usingFallback;

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

  /// Aggregate'te view_count yok; en yeni + featured ağırlıklı.
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

  /// Kullanıcının seçtiği kaynak listesini güncelleyip yeniden çek.
  /// Onboarding bittikten sonra ve "Kaynak Tercihleri" ekranından
  /// kaydedildikten sonra çağrılır.
  Future<void> applySources(List<NewsSource> sources) async {
    _lastSourceList = sources;
    await _load();
  }

  /// İlk açılış — varsayılan olarak önerilenleri çek.
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
        _all = await _loadMockFallback();
        _activeSources = const [];
        _usingFallback = true;
      } else {
        final fetched = await _rss.aggregate(_lastSourceList, perSource: 8);
        if (fetched.isNotEmpty) {
          _all = fetched;
          _activeSources = _lastSourceList;
          _usingFallback = false;
        } else {
          _all = await _loadMockFallback();
          _activeSources = _lastSourceList;
          _usingFallback = true;
        }
      }
    } catch (e) {
      _lastError = 'Canlı haberler alınamadı: $e';
      _all = await _loadMockFallback();
      _usingFallback = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Article>> _loadMockFallback() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return MockNewsData.articles;
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
