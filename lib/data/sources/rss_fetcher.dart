import '../models/article.dart';
import '../models/news_source.dart';
import '../repositories/rss_news_service.dart';
import 'news_fetcher.dart';

/// Kaynağın RSS/Atom feed'i — her planın son (yedek) halkası.
class RssFetcher extends NewsFetcher {
  const RssFetcher(this._rss);

  final RssNewsService _rss;

  @override
  String get label => 'RSS';

  @override
  bool supportsCategory(String? category) => true;

  @override
  Future<List<Article>> fetch(
    NewsSource source, {
    required int limit,
    String? category,
  }) =>
      _rss.fetchOneOrThrow(source, category: category, limit: limit);
}
