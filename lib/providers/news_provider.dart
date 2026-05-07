import 'package:flutter/foundation.dart';

import '../core/network/api_config.dart';
import '../data/models/article.dart';
import '../data/models/category.dart';
import '../data/repositories/api_news_repository.dart';
import '../data/repositories/mock_news_repository.dart';
import '../data/repositories/news_repository.dart';

class NewsProvider extends ChangeNotifier {
  NewsProvider({NewsRepository? repository})
      : _repository = repository ??
            (ApiConfig.useApi
                ? ApiNewsRepository()
                : MockNewsRepository()) {
    _load();
  }

  final NewsRepository _repository;

  bool _loading = true;
  String? _lastError;
  List<Article> _all = const [];
  String _selectedCategoryId = NewsCategory.all.id;

  bool get loading => _loading;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;

  String get selectedCategoryId => _selectedCategoryId;
  NewsCategory get selectedCategory =>
      NewsCategory.byId(_selectedCategoryId);

  List<Article> get featured =>
      _all.where((a) => a.isFeatured).toList(growable: false);

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
      _all = await _repository.fetchAll();
    } catch (e) {
      _lastError = 'Haberler yüklenemedi: $e';
      // Network başarısız ise mock'a düş, ama hatayı korur (banner için).
      if (_repository is! MockNewsRepository) {
        try {
          _all = await MockNewsRepository().fetchAll();
        } catch (_) {
          _all = const [];
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
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
