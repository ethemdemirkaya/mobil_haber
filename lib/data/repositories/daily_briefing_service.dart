import '../models/article.dart';
import '../models/category.dart';

/// Brifingin odaklanacağı kategori bilgisi.
///
/// `category == null` ya da `NewsCategory.all` → genel gündem.
/// Aksi halde sadece o kategoriye giren makaleler kullanılır ve prompt
/// "spor gündemi", "ekonomi gündemi" gibi uyarlanır.
class BriefingTopic {
  const BriefingTopic({this.category});

  final NewsCategory? category;

  bool get isGeneral =>
      category == null || category!.id == NewsCategory.all.id;

  /// "Genel gündem", "Spor gündemi", "Ekonomi gündemi" şeklinde başlık.
  String get displayName {
    if (isGeneral) return 'Genel gündem';
    return '${category!.name} gündemi';
  }

  /// Cache anahtarı (PreferencesProvider veya in-memory).
  String get cacheKey => category?.id ?? NewsCategory.all.id;
}

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

  /// Genel ve kategori-bazlı brifing için ortak system prompt'u üretir.
  /// Kategori varsa "spor brifingi", "ekonomi brifingi" gibi konu odaklı
  /// olur ve "kategori değiştiğinde geçiş" kuralı kalkar.
  static String systemPromptFor(BriefingTopic topic) {
    final scope = topic.isGeneral
        ? 'günün ana gündem haberlerinden'
        : 'günün ${topic.category!.name.toLowerCase()} haberlerinden';
    final transitionRule = topic.isGeneral
        ? '- Kategori değiştiğinde yumuşak geçiş yap ("Spora geçelim", '
            '"Ekonomi tarafında", "Dünyadan ise" gibi).'
        : '- Tüm haberler aynı konuda olduğu için yumuşak geçişler '
            'gerekmez; haberler arasında "öte yandan", "bunun yanında", '
            '"ayrıca" gibi bağlaçlar yeterlidir.';
    final intro = topic.isGeneral
        ? '"Merhaba, ben Pusula" diye başla ve günün özeti olduğunu '
            'belirt.'
        : '"Merhaba, ben Pusula. ${topic.displayName} ile karşınızdayım" '
            'diye başla.';
    return '''
Sen Pusula adlı Türkçe haber uygulamasının sesli sunucususun. Görevin,
verilen $scope 90-120 saniye sürecek (yaklaşık 250-300 kelime) bir
sözlü ${topic.displayName.toLowerCase()} brifingi hazırlamak.

Akış kuralları:
- Doğal bir radyo spikeri tonunda yaz; $intro
- 5-7 haberi ele al; her birine 1-2 cümle ayır.
$transitionRule
- Sayıları ve özel isimleri olduğu gibi koru.
- Kısaltma kullanma (örn. "TL" yerine "Türk lirası", "AB" yerine "Avrupa
  Birliği"). TTS daha doğru okur.
- Spekülasyon yapma, sadece verilen başlık+özet bilgisinden yola çık.
- "Pusula'da kalın, iyi günler dileriz" ile kapat.
- Çıktın SADECE metin olsun, madde işareti veya başlık koyma —
  doğrudan TTS okuyacak.
''';
  }

  /// Geriye dönük uyumluluk: eski sürümde sabit prompt kullanılıyordu.
  static const String systemPrompt = '''
Sen Pusula adlı Türkçe haber uygulamasının sesli sunucususun. Görevin,
verilen güncel haber listesinden 90-120 saniye sürecek (yaklaşık 250-300
kelime) bir sözlü gündem brifingi hazırlamak.

Akış kuralları:
- Doğal bir radyo spikeri tonunda yaz; "Merhaba, ben Pusula" diye başla.
- 5-7 haberi ele al; her birine 1-2 cümle ayır.
- Sayıları ve özel isimleri koru.
- Kısaltma açma (TL → Türk lirası).
- "Pusula'da kalın, iyi günler dileriz" ile kapat.
''';

  /// AI'a gönderilecek user-prompt'u inşa eder. `topic` belirtilirse
  /// kategori odaklı; yoksa genel gündem.
  String buildUserPrompt({
    required List<Article> articles,
    required DateTime now,
    BriefingTopic topic = const BriefingTopic(),
  }) {
    if (articles.isEmpty) {
      return 'Bugün için ${topic.displayName.toLowerCase()} kapsamında '
          'haber yok. Kullanıcıya kısa ve nazik bir bilgi mesajı ver.';
    }
    final dateStr = _formatDate(now);
    final buffer = StringBuffer()
      ..writeln('Tarih: $dateStr')
      ..writeln('Konu: ${topic.displayName}')
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

  /// Uzun bir metni cümle sınırlarında parçalara böler. Android TTS'inde
  /// `speak()` çağrısının ~4000 karakter limiti var; bunun altında bile
  /// uzun metinlerde kelime ortasında kesilme oluyor. Cümle bazlı parçalama
  /// + sıraya alıp ardışık `speak()` ile her cümleyi ayrı çalmak daha
  /// stabil.
  ///
  /// Türkçe noktalama: `.`, `!`, `?`. Ayrıca `…` ve `\n\n`. Kısa parçacıkları
  /// (≤ 3 kelime) önceki/sonraki cümleyle birleştirir.
  List<String> splitIntoUtterances(String text, {int maxChars = 220}) {
    if (text.trim().isEmpty) return const [];
    // Newline → space (cümle bütünlüğü için)
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Cümle sonu işaretinden sonraki boşlukta böl.
    final parts = flat
        .split(RegExp(r'(?<=[\.!\?…])\s+'))
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList(growable: false);

    // Çok kısa parçaları sonrakine yapıştır.
    final merged = <String>[];
    for (final p in parts) {
      if (merged.isNotEmpty &&
          (p.length < 12 || merged.last.length + p.length < maxChars)) {
        if (merged.last.length + p.length < maxChars) {
          merged[merged.length - 1] = '${merged.last} $p';
          continue;
        }
      }
      merged.add(p);
    }
    return merged;
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
