// Run after audit_news_sources.py; exercises the real production extractor
// against local HTML captures without issuing further network requests.
import 'dart:convert';
import 'dart:io';

import 'package:pusula_news/data/repositories/article_text_extractor.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('dart run tool/audit_article_extractor.dart <audit.json>');
    exitCode = 64;
    return;
  }
  final file = File(args.single);
  final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  var checked = 0;
  var extracted = 0;
  for (final source in report['results'] as List) {
    for (final detail in source['details'] as List) {
      final path = detail['scratch_html'] as String?;
      if (path == null) continue;
      final html = utf8.decode(
        File(path).readAsBytesSync(),
        allowMalformed: true,
      );
      final text = ArticleTextExtractor.extractFromHtml(html);
      detail['current_dart_extractor_chars'] = text?.length ?? 0;
      detail['current_dart_extractor_paragraphs'] = text == null
          ? 0
          : text.split('\n\n').length;
      checked++;
      if (text != null) extracted++;
    }
  }
  report['current_extractor_comparison'] = {
    'checked': checked,
    'nonempty': extracted,
    'max_chars': ArticleTextExtractor.maxChars,
    'method':
        'Actual ArticleTextExtractor.extractFromHtml on identical captured HTML',
  };
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Production extractor returned text for $extracted/$checked captured pages.',
  );
}
