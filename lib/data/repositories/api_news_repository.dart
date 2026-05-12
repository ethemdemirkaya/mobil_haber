import '../../core/network/api_client.dart';
import '../models/article.dart';
import 'news_repository.dart';

class ApiNewsRepository implements NewsRepository {
  ApiNewsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<Article>> fetchAll() async {
    final raw = await _client.get('/articles', query: {'limit': '100'});
    return _decodeList(raw);
  }

  @override
  Future<List<Article>> fetchFeatured() async {
    final raw = await _client.get('/articles/featured');
    return _decodeList(raw);
  }

  List<Article> _decodeList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_decodeArticle)
        .toList(growable: false);
  }

  Article _decodeArticle(Map<String, dynamic> json) {
    return Article(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? 'all',
      imageUrl: json['imageUrl']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Anonim',
      publishedAt: _parseDate(json['publishedAt']),
      readMinutes: (json['readMinutes'] as num?)?.toInt() ?? 3,
      isFeatured: json['isFeatured'] == true,
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value.replaceAll(' ', 'T')) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
