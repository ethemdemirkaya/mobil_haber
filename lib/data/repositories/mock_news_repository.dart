import '../mock/mock_news_data.dart';
import '../models/article.dart';
import 'news_repository.dart';

class MockNewsRepository implements NewsRepository {
  @override
  Future<List<Article>> fetchAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return MockNewsData.articles;
  }

  @override
  Future<List<Article>> fetchFeatured() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MockNewsData.featured();
  }
}
