import '../models/article.dart';
import '../models/category.dart';

/// Sesli günlük brifing oluşturan servis.
///
/// `NewsProvider`'dan gelen son haberleri AI'a göndermek üzere hazırlar
/// (prompt template) ve dönen metni TTS'in akıcı okuyabileceği şekilde
/// hafifçe temizler.
///
/// Bu sınıf doğrudan `OpenRouterClient`'ı çağırmaz — `AiSettingsProvider`
/// üzerinden geçer (kullanıcı ayarlarını ve key kaynağını orası bilir).
class DailyBriefingService {
  DailyBriefingService();

  static const String systemPrompt = '''
Sen Pusula adlı Türkçe haber uygulamasının sesli sunucususun. Görevin,
verilen güncel haber listesinden 90-120 saniye sürecek (yaklaşık 250-300
kelime) bir sözlü gündem brifingi hazırlamak.

Akış kuralları:
- Doğal bir radyo spikeri tonunda yaz; "Merhaba, ben Pusula" diye başla
  ve günün özeti olduğunu belirt.
- 5-7 haberi ele al; her birine 1-2 cümle ayır.
- Kategori değiştiğinde yumuşak geçiş yap ("Spora geçelim", "Ekonomi
  tarafında", "Dünyadan ise" gibi).
- Sayıları ve özel isimleri olduğu gibi koru.
- Kısaltma kullanma (örn. "TL" yerine "Türk lirası", "AB" yerine "Avrupa
  Birliği"). TTS daha doğru okur.
- Spekülasyon yapma, sadece verilen başlık+özet bilgisinden yola çık.
- "Merhaba" ile aç, "Pusula'da kalın, iyi günler dileriz" ile kapat.
- Çıktın SADECE metin olsun, madde işareti veya başlık koyma —
  doğrudan TTS okuyacak.
''';

  /// AI'a gönderilecek user-prompt'u inşa eder.
  String buildUserPrompt({
    required List<Article> articles,
    required DateTime now,
  }) {
    if (articles.isEmpty) {
      return 'Bugün için elimizde haber yok. Kullanıcıya kısa ve nazik bir '
          'bilgi mesajı ver.';
    }
    final dateStr = _formatDate(now);
    final buffer = StringBuffer()
      ..writeln('Tarih: $dateStr')
      ..writeln('Aşağıdaki haberlerden bir sesli brifing hazırla:\n');
    for (var i = 0; i < articles.length; i++) {
      final a = articles[i];
      final cat = NewsCategory.byId(a.categoryId).name;
      buffer
        ..writeln('${i + 1}. [$cat] ${a.title}')
        ..writeln('   Kaynak: ${a.sourceName}')
        ..writeln(
          '   Özet: ${a.summary.isNotEmpty ? a.summary : (a.content.length > 240 ? "${a.content.substring(0, 240)}..." : a.content)}',
        )
        ..writeln();
    }
    return buffer.toString();
  }

  /// AI cevabını TTS'in okuması için hafifçe temizle: madde başları, fazla
  /// boşluklar, AI'ın bazen koyduğu emojiler vb.
  String sanitizeForSpeech(String raw) {
    var s = raw
        // Madde başları
        .replaceAll(RegExp(r'^\s*[•*\-]\s+', multiLine: true), '')
        // Markdown başlıklar
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        // Bold/italic markers
        .replaceAll(RegExp(r'(\*\*|__|`)'), '')
        // Emoji aralıkları (basitleştirilmiş — ana 4 plane)
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}]',
            unicode: true,
          ),
          '',
        )
        // Çoklu boşluk
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        // Çoklu newline → tek
        .replaceAll(RegExp(r'\n{2,}'), '\n');
    return s.trim();
  }

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  static const _weekdays = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];

  String _formatDate(DateTime d) {
    final wd = _weekdays[(d.weekday - 1) % 7];
    return '${d.day} ${_months[d.month - 1]} ${d.year}, $wd';
  }
}
