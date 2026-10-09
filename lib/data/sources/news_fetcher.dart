import '../models/article.dart';
import '../models/news_source.dart';

/// Bir kaynaktan haber listesi alan tek bir yöntem (RSS, WordPress REST,
/// yayıncının kendi API'si …).
///
/// Bir kaynağın çekim planı birden çok yöntemden oluşur; ilki başarısız
/// olursa (istisna ya da boş liste) sıradaki denenir. Böylece bir
/// yayıncı API'sini kapatsa ya da şemasını değiştirse kaynak tamamen
/// kaybolmaz.
abstract class NewsFetcher {
  const NewsFetcher();

  /// Tanılama ekranında gösterilen yöntem adı.
  String get label;

  /// Bu yöntem verilen kategori feed'ini sunabiliyor mu? (Ör. WordPress
  /// API'si kategori kimliklerini bilmeden kategori süzemez; o durumda
  /// RSS'in kategori feed'ine geçilir.)
  bool supportsCategory(String? category) => category == null;

  Future<List<Article>> fetch(
    NewsSource source, {
    required int limit,
    String? category,
  });
}

/// Bir kaynaktan alınan sonuç ve hangi yöntemle alındığı.
class FetchOutcome {
  const FetchOutcome(this.articles, {required this.method, this.errors = const []});

  final List<Article> articles;

  /// Başarılı yöntemin adı; hiçbiri çalışmadıysa `null`.
  final String? method;

  /// Başarısız denemelerin "yöntem: hata" açıklamaları.
  final List<String> errors;
}
