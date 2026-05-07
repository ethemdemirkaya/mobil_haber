import '../models/article.dart';

abstract class NewsRepository {
  Future<List<Article>> fetchAll();
  Future<List<Article>> fetchFeatured();
}
