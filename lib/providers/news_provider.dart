import 'package:flutter/foundation.dart';

import '../core/network/api_config.dart';
import '../data/mock/mock_news_data.dart';
import '../data/models/article.dart';
import '../data/models/category.dart';
import '../data/repositories/external_news_repository.dart';

/// **mobil_haber özetleyici** — birincil veri kaynağı
/// `ExternalNewsRepository.fetchAggregate()`. Başarısız olursa mock'a düşer
/// (offline / API yoksa development).
class NewsProvider extends ChangeNotifier {
  NewsProvider({ExternalNewsRepository? aggregateRepo})
      : _aggregateRepo = aggregateRepo ??
            (ApiConfig.useApi ? ExternalNewsRepository() : null) {
    _load();
  }

  final ExternalNewsRepository? _aggregateRepo;

  bool _loading = true;
  String? _lastError;
  bool _usingFallback = false;
  List<Article> _all = const [];
  String _selectedCategoryId = NewsCategory.all.id;

  bool get loading => _loading;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;
  bool get usingFallback => _usingFallback;

  String get selectedCategoryId => _selectedCategoryId;
  NewsCategory get selectedCategory =>
      NewsCategory.byId(_selectedCategoryId);

  List<Article> get featured {
    // Aggregate'ten geldiğinde isFeatured bayrağı yok; en yeni 5 makaleyi
    // "öne çıkan" olarak göster.
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

  /// "En çok okunanlar" — aggregate'te view_count yok, en yeni + öne çıkan.
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

  Future<void> _load() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      if (_aggregateRepo != null) {
        // Aggregate'ten canlı çek (12 sn timeout, perSource küçük)
        final agg = await _aggregateRepo.fetchAggregate(perSource: 8);
        if (agg.isNotEmpty) {
          _all = agg;
          _usingFallback = false;
        } else {
          _all = await _loadMockFallback();
          _usingFallback = true;
        }
      } else {
        _all = await _loadMockFallback();
        _usingFallback = true;
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
