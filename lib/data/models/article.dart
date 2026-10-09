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
    this.sourceId = '',
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

  /// `NewsSourceCatalog` id'si (ör. "ntv"). Eski cache/bookmark
  /// kayıtlarında boş olabilir; o durumda [sourceName] üzerinden eşlenir.
  final String sourceId;

  bool get hasOriginalUrl => sourceUrl.isNotEmpty;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'content': content,
        'categoryId': categoryId,
        'imageUrl': imageUrl,
        'author': author,
        'publishedAt': publishedAt.toIso8601String(),
        'readMinutes': readMinutes,
        'isFeatured': isFeatured,
        'sourceUrl': sourceUrl,
        'sourceName': sourceName,
        'sourceId': sourceId,
      };

  /// Kalıcı kayıttan (cache, bookmark, geçmiş) okur. id yoksa null.
  static Article? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return Article(
      id: id,
      title: raw['title']?.toString() ?? '',
      summary: raw['summary']?.toString() ?? '',
      content: raw['content']?.toString() ?? '',
      categoryId: raw['categoryId']?.toString() ?? 'gundem',
      imageUrl: raw['imageUrl']?.toString() ?? '',
      author: raw['author']?.toString() ?? 'Anonim',
      publishedAt:
          DateTime.tryParse(raw['publishedAt']?.toString() ?? '') ??
              DateTime.now(),
      readMinutes: (raw['readMinutes'] as num?)?.toInt() ?? 1,
      isFeatured: raw['isFeatured'] == true,
      sourceUrl: raw['sourceUrl']?.toString() ?? '',
      sourceName: raw['sourceName']?.toString() ?? '',
      sourceId: raw['sourceId']?.toString() ?? '',
    );
  }

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
