// Research harness: parse captured live feed bytes through the real app parser.
// First run audit_news_sources.py with --details 0 and the output path below.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pusula_news/data/models/news_source.dart';
import 'package:pusula_news/data/repositories/rss_news_service.dart';

void main() {
  test(
    'Audit production RSS parser against captured live primary feeds',
    () async {
      const path = String.fromEnvironment(
        'AUDIT_JSON',
        defaultValue: 'docs/research/news-rss-parser-audit.json',
      );
      final file = File(path);
      final report =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final row in report['results'] as List) {
        final source = NewsSourceCatalog.byId(row['source']['id'] as String)!;
        final probe = row['primary'] as Map<String, dynamic>;
        final captured = probe['scratch_feed'] as String?;
        if (captured == null) continue;
        final client = MockClient(
          (_) async => http.Response.bytes(
            File(captured).readAsBytesSync(),
            probe['status'] as int,
            headers: {'content-type': probe['content_type'] as String},
          ),
        );
        try {
          final articles = await RssNewsService(
            httpClient: client,
          ).fetchOne(source, limit: 5000);
          row['app_parser_items'] = articles.length;
          row['app_empty_image_items'] = articles
              .where((article) => article.imageUrl.isEmpty)
              .length;
          row['app_future_date_items'] = articles
              .where(
                (article) => article.publishedAt.isAfter(
                  DateTime.now().add(const Duration(minutes: 15)),
                ),
              )
              .length;
          row['app_content_400_items'] = articles
              .where((article) => article.content.length >= 400)
              .length;
        } finally {
          client.close();
        }
      }
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
      expect((report['results'] as List).length, NewsSourceCatalog.all.length);
    },
  );
}
