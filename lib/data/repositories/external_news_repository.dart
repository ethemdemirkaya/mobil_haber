import '../../core/network/api_client.dart';
import '../models/article.dart';

class ExternalSource {
  const ExternalSource({
    required this.id,
    required this.name,
    required this.requiresApiKey,
    required this.available,
  });

  final String id;
  final String name;
  final bool requiresApiKey;
  final bool available;

  factory ExternalSource.fromJson(Map<String, dynamic> json) {
    return ExternalSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      requiresApiKey: json['requiresApiKey'] == true,
      available: json['available'] == true,
    );
  }
}

class ExternalNewsRepository {
  ExternalNewsRepository({ApiClient? client})
      : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<ExternalSource>> fetchSources() async {
    final raw = await _client.get('/external/sources');
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ExternalSource.fromJson)
        .toList(growable: false);
  }

  Future<List<Article>> fetchFromSource(
    String sourceId, {
    String query = '',
    String category = '',
    int limit = 20,
  }) async {
    final raw = await _client.get('/external/articles', query: {
      'source': sourceId,
      if (query.isNotEmpty) 'q': query,
      if (category.isNotEmpty) 'category': category,
      'limit': '$limit',
    });
    return _decodeList(raw);
  }

  Future<List<Article>> fetchAggregate({
    List<String>? sources,
    String query = '',
    String category = '',
    int perSource = 8,
  }) async {
    // Aggregate, çoklu kaynağı sırayla çekiyor — varsayılan 4 sn yetmez.
    final raw = await _client.get(
      '/external/aggregate',
      query: {
        if (sources != null && sources.isNotEmpty)
          'sources': sources.join(','),
        if (query.isNotEmpty) 'q': query,
        if (category.isNotEmpty) 'category': category,
        'perSource': '$perSource',
      },
      timeout: const Duration(seconds: 45),
    );
    return _decodeList(raw);
  }

  Future<List<Article>> fetchSingleSource(
    String sourceId, {
    String query = '',
    String category = '',
    int limit = 30,
  }) async {
    // Tek kaynakta da bazı RSS sunucuları yavaş olabiliyor.
    return _decodeList(await _client.get(
      '/external/articles',
      query: {
        'source': sourceId,
        if (query.isNotEmpty) 'q': query,
        if (category.isNotEmpty) 'category': category,
        'limit': '$limit',
      },
      timeout: const Duration(seconds: 15),
    ));
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
      categoryId: json['categoryId']?.toString() ?? 'gundem',
      imageUrl: json['imageUrl']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Anonim',
      publishedAt: _parseDate(json['publishedAt']),
      readMinutes: (json['readMinutes'] as num?)?.toInt() ?? 1,
      isFeatured: json['isFeatured'] == true,
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
