import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/article.dart';
import '../models/news_source.dart';
import '../repositories/rss_news_service.dart';
import 'haberturk_fetcher.dart';
import 'news_fetcher.dart';
import 'rss_fetcher.dart';
import 'wordpress_fetcher.dart';

/// Kaynak başına çekim planlarını yürütüp haberleri birleştirir.
///
/// Her kaynağın kendi planı vardır: önce yayıncının doğrulanmış API'si,
/// o başarısız olursa (hata ya da boş liste) RSS. Planlar Ekim 2026'da 56
/// kaynak tek tek yoklanarak çıkarıldı (bkz. docs/research/
/// source-fetch-plan.md). API'si bulunamayan kaynaklar doğrudan RSS'le
/// çekilir.
class NewsAggregator {
  NewsAggregator({http.Client? client, RssNewsService? rss})
      : _rss = rss ?? RssNewsService(httpClient: client),
        _client = client;

  final RssNewsService _rss;
  final http.Client? _client;

  static const Duration _perMethodTimeout = Duration(seconds: 12);

  /// Doğrulanmış yayıncı API'leri. Burada olmayan kaynaklar RSS'le çekilir.
  late final Map<String, List<NewsFetcher>> _apiFetchers = {
    // WordPress REST: liste + tam gövde + öne çıkan görsel + UTC tarih.
    'diken': [WordPressFetcher('https://www.diken.com.tr', client: _client)],
    'medyascope': [WordPressFetcher('https://medyascope.tv', client: _client)],
    'shiftdelete': [WordPressFetcher('https://shiftdelete.net', client: _client)],
    // Habertürk'ün kendi kategori API'si (gündem, dünya).
    'haberturk': [HaberturkFetcher(client: _client)],
  };

  /// [source] için sırayla denenecek yöntemler (en sonda daima RSS).
  List<NewsFetcher> planFor(NewsSource source) => [
        ...?_apiFetchers[source.id],
        RssFetcher(_rss),
      ];

  /// Tek kaynaktan çek; plandaki yöntemleri sırayla dener.
  Future<FetchOutcome> fetchSource(
    NewsSource source, {
    required int limit,
    String? category,
  }) async {
    final errors = <String>[];
    for (final fetcher in planFor(source)) {
      if (!fetcher.supportsCategory(category)) continue;
      try {
        final articles = await fetcher
            .fetch(source, limit: limit, category: category)
            .timeout(_perMethodTimeout);
        if (articles.isNotEmpty) {
          return FetchOutcome(articles, method: fetcher.label, errors: errors);
        }
        errors.add('${fetcher.label}: boş liste');
      } catch (e) {
        errors.add('${fetcher.label}: $e');
        debugPrint('[Pusula][Fetch] ${source.id} ${fetcher.label} başarısız: $e');
      }
    }
    return FetchOutcome(const [], method: null, errors: errors);
  }

  /// Kaynakları paralel çeker, birleştirir ve yayın tarihine göre sıralar.
  /// Aynı haber iki yöntemden gelirse (kimlik aynı) bir kez alınır.
  Future<List<Article>> aggregate(
    List<NewsSource> sources, {
    String? category,
    int perSource = 8,
  }) async {
    if (sources.isEmpty) return const [];
    final outcomes = await Future.wait(sources.map(
      (s) => fetchSource(s, limit: perSource, category: category),
    ));
    final seen = <String>{};
    final all = <Article>[
      for (final o in outcomes)
        for (final a in o.articles)
          if (seen.add(a.id)) a,
    ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return all;
  }

  /// Tanılama: kaynağın planını çalıştırır; hangi yöntemle kaç haber
  /// alındığını ya da neden alınamadığını döndürür.
  Future<FeedProbe> probe(NewsSource source) async {
    final sw = Stopwatch()..start();
    final outcome = await fetchSource(source, limit: 10);
    final ok = outcome.articles.isNotEmpty;
    final fallbackNote = ok && outcome.errors.isNotEmpty
        ? ' (önceki yöntem başarısız: ${outcome.errors.first.split(':').first})'
        : '';
    return FeedProbe(
      source: source,
      ok: ok,
      itemCount: outcome.articles.length,
      latency: sw.elapsed,
      message: ok
          ? '${outcome.method} · ${outcome.articles.length} haber$fallbackNote'
          : (outcome.errors.isEmpty
              ? 'Haber alınamadı'
              : outcome.errors.join(' · ')),
    );
  }

  void close() => _rss.close();
}
