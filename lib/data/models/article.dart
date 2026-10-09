import '../../core/utils/turkish_text.dart';
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
    this.sourceUrl = '',
    this.sourceName = '',
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

  /// Orijinal habere bağlanan URL (varsa). Aggregate'ten gelen makaleler bunu
  /// taşır; mock seed makaleler boş bırakır.
  final String sourceUrl;

  /// İnsan-okuyabilir kaynak adı (ör. "TRT Haber", "Anadolu Ajansı").
  final String sourceName;

  bool get hasOriginalUrl => sourceUrl.isNotEmpty;

  NewsCategory get category => NewsCategory.byId(categoryId);

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    // Türkçe büyük/küçük harf ve klavye farkları ("saglik" ⇔ "SAĞLIK")
    // eşleşmeyi bozmasın.
    final q = foldTr(query.trim());
    return foldTr(title).contains(q) ||
        foldTr(summary).contains(q) ||
        foldTr(author).contains(q) ||
        foldTr(category.name).contains(q);
  }
}
