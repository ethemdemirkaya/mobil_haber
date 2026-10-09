/// HTML parçalarını düz metne çeviren yardımcılar (RSS açıklamaları ve
/// makale sayfaları için ortak).
library;

final RegExp _br = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _pClose = RegExp(r'</p>', caseSensitive: false);
final RegExp _tag = RegExp(r'<[^>]*>');
final RegExp _ws = RegExp(r'\s+');

/// Etiketleri söker, `<br>`/`</p>` yerine boşluk bırakır, boşlukları
/// sadeleştirir.
String stripHtml(String html) {
  if (html.isEmpty) return '';
  return html
      .replaceAll(_br, ' ')
      .replaceAll(_pClose, ' ')
      .replaceAll(_tag, '')
      .replaceAll(_ws, ' ')
      .trim();
}

final RegExp _decimalEntity = RegExp(r'&#(\d+);');
final RegExp _hexEntity = RegExp(r'&#x([0-9a-fA-F]+);');

/// Yaygın isimli ve sayısal HTML entity'lerini çözer.
String decodeHtmlEntities(String s) {
  if (s.isEmpty || !s.contains('&')) return s;
  return s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&hellip;', '…')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAllMapped(_decimalEntity, (m) {
        final code = int.tryParse(m.group(1) ?? '');
        return code == null ? m.group(0)! : String.fromCharCode(code);
      })
      .replaceAllMapped(_hexEntity, (m) {
        final code = int.tryParse(m.group(1) ?? '', radix: 16);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      });
}
