import 'category.dart';

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.categoryId,
    required this.imageUrl,
    required this.author,
    required this.publishedAt,
    required this.readMinutes,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String summary;
  final String content;
  final String categoryId;
  final String imageUrl;
  final String author;
  final DateTime publishedAt;
  final int readMinutes;
  final bool isFeatured;

  NewsCategory get category => NewsCategory.byId(categoryId);

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    return title.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        author.toLowerCase().contains(q) ||
        category.name.toLowerCase().contains(q);
  }
}
