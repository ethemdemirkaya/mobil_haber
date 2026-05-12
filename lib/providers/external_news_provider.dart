import 'package:flutter/foundation.dart';

import '../data/models/article.dart';
import '../data/repositories/external_news_repository.dart';

class ExternalNewsProvider extends ChangeNotifier {
  ExternalNewsProvider({ExternalNewsRepository? repository})
      : _repository = repository ?? ExternalNewsRepository();

  final ExternalNewsRepository _repository;

  bool _loadingSources = false;
  bool _loadingArticles = false;
  String? _error;

  List<ExternalSource> _sources = const [];
  List<Article> _articles = const [];
  String? _selectedSourceId;

  bool get loadingSources => _loadingSources;
  bool get loadingArticles => _loadingArticles;
  String? get error => _error;

  List<ExternalSource> get sources => _sources;
  List<ExternalSource> get availableSources =>
      _sources.where((s) => s.available).toList(growable: false);

  /// Kullanıcının tercihiyle filtrelenmiş kaynak listesi.
  List<ExternalSource> visibleSources(Set<String> disabled) =>
      _sources
          .where((s) => s.available && !disabled.contains(s.id))
          .toList(growable: false);

  List<Article> get articles => _articles;
  String? get selectedSourceId => _selectedSourceId;

  ExternalSource? get selectedSource {
    if (_selectedSourceId == null) return null;
    for (final s in _sources) {
      if (s.id == _selectedSourceId) return s;
    }
    return null;
  }

  Future<void> loadSources() async {
    _loadingSources = true;
    _error = null;
    notifyListeners();
    try {
      _sources = await _repository.fetchSources();
      // Varsayılan: ilk available kaynak
      if (_selectedSourceId == null) {
        final first = _sources.firstWhere(
          (s) => s.available,
          orElse: () => _sources.isEmpty
              ? const ExternalSource(
                  id: '',
                  name: '',
                  requiresApiKey: false,
                  available: false,
                )
              : _sources.first,
        );
        if (first.id.isNotEmpty) _selectedSourceId = first.id;
      }
    } catch (e) {
      _error = 'Kaynaklar yüklenemedi: $e';
    } finally {
      _loadingSources = false;
      notifyListeners();
    }
  }

  Future<void> selectSource(String id) async {
    if (_selectedSourceId == id) return;
    _selectedSourceId = id;
    _articles = const [];
    notifyListeners();
    await loadArticles();
  }

  Future<void> loadArticles({String query = ''}) async {
    if (_selectedSourceId == null) return;
    _loadingArticles = true;
    _error = null;
    notifyListeners();
    try {
      _articles = await _repository.fetchSingleSource(
        _selectedSourceId!,
        query: query,
        limit: 30,
      );
    } catch (e) {
      _error = 'Haberler yüklenemedi: $e';
      _articles = const [];
    } finally {
      _loadingArticles = false;
      notifyListeners();
    }
  }

  Future<void> loadAggregated({String query = ''}) async {
    _loadingArticles = true;
    _error = null;
    _selectedSourceId = null;
    notifyListeners();
    try {
      _articles = await _repository.fetchAggregate(
        query: query,
        perSource: 6,
      );
    } catch (e) {
      _error = 'Haberler yüklenemedi: $e';
      _articles = const [];
    } finally {
      _loadingArticles = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
