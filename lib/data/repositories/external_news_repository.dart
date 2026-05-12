import '../models/article.dart';
import '../models/news_source.dart';
import 'rss_news_service.dart';

/// `LiveNewsScreen` ve `SourcePreferencesScreen` ile arayüz uyumluluğu için
/// korunan basit kaynak özeti.
///
/// **NOT:** v2 mimaride bu sınıf artık PHP backend'i çağırmıyor; doğrudan
/// `NewsSourceCatalog`'tan beslenir. Eski PHP `/external/*` endpoint'leri
/// projeden kaldırılmadı ama Flutter tarafı backend bağımlılığı olmadan
/// çalışır.
class ExternalSource {
  const ExternalSource({
    required this.id,
    required this.name,
    required this.requiresApiKey,
    required this.available,
    this.logoUrl = '',
    this.tagline = '',
    this.domain = '',
  });

  final String id;
  final String name;
  final bool requiresApiKey;
  final bool available;

  final String logoUrl;
  final String tagline;
  final String domain;

  factory ExternalSource.fromCatalog(NewsSource s) {
    return ExternalSource(
      id: s.id,
      name: s.name,
      requiresApiKey: false,
      available: true,
      logoUrl: s.logoUrl,
      tagline: s.tagline,
      domain: s.domain,
    );
  }
}

/// `mobil_haber` haricinde haber çeken katman.
///
/// v2 mimaride RSS doğrudan istemci tarafında parse edilir
/// ([RssNewsService]). Bu sınıfın public sözleşmesi (eski PHP backend'iyle
/// konuşan sürümle aynı) korunarak `live_news_screen.dart` ve diğer
/// çağıranların değişmeden çalışması sağlanmıştır.
class ExternalNewsRepository {
  ExternalNewsRepository({RssNewsService? service})
      : _service = service ?? RssNewsService();

  final RssNewsService _service;

  Future<List<ExternalSource>> fetchSources() async {
    return NewsSourceCatalog.all
        .map(ExternalSource.fromCatalog)
        .toList(growable: false);
  }

  Future<List<Article>> fetchSingleSource(
    String sourceId, {
    String query = '',
    String category = '',
    int limit = 30,
  }) async {
    final src = NewsSourceCatalog.byId(sourceId);
    if (src == null) return const [];
    final articles = await _service.fetchOne(
      src,
      category: category.isEmpty ? null : category,
      limit: limit,
    );
    if (query.isEmpty) return articles;
    return articles.where((a) => a.matchesQuery(query)).toList(growable: false);
  }

  Future<List<Article>> fetchFromSource(
    String sourceId, {
    String query = '',
    String category = '',
    int limit = 20,
  }) =>
      fetchSingleSource(
        sourceId,
        query: query,
        category: category,
        limit: limit,
      );

  /// `sources` verilirse sadece o id'ler kullanılır; aksi halde
  /// kataloğun tamamı. UI tarafı kullanıcı tercihine göre filtreleyip
  /// gönderiyor.
  Future<List<Article>> fetchAggregate({
    List<String>? sources,
    String query = '',
    String category = '',
    int perSource = 8,
  }) async {
    final list = <NewsSource>[];
    if (sources != null && sources.isNotEmpty) {
      for (final id in sources) {
        final s = NewsSourceCatalog.byId(id);
        if (s != null) list.add(s);
      }
    } else {
      list.addAll(NewsSourceCatalog.all);
    }
    final articles = await _service.aggregate(
      list,
      category: category.isEmpty ? null : category,
      perSource: perSource,
    );
    if (query.isEmpty) return articles;
    return articles.where((a) => a.matchesQuery(query)).toList(growable: false);
  }
}
