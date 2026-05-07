import 'package:flutter/foundation.dart';

import '../data/mock/mock_news_data.dart';
import '../data/models/article.dart';
import '../data/models/category.dart';

class NewsProvider extends ChangeNotifier {
  NewsProvider() {
    _load();
  }

  bool _loading = true;
  List<Article> _all = const [];
  String _selectedCategoryId = NewsCategory.all.id;

  bool get loading => _loading;
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
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _all = MockNewsData.articles;
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _all = MockNewsData.articles;
    _loading = false;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }
}
