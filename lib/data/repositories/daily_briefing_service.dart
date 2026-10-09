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
- Listedeki haberlerin her birine sırayla 1-2 cümle ayır; listede olmayan
  haber ekleme.
$transitionRule
- YALNIZCA verilen başlık ve özetteki bilgiyi kullan. Özeti "yok" olan
  haberi yalnızca başlıktaki kadarıyla, tek cümleyle an. İsim, sayı,
  tarih, neden ya da sonuç uydurma; tahmin yürütme, yorum katma.
- Sayıları ve özel isimleri olduğu gibi koru.
- Kısaltma kullanma (örn. "TL" yerine "Türk lirası", "AB" yerine "Avrupa
  Birliği"); yüzdeleri "yüzde 5" biçiminde yaz. TTS daha doğru okur.
- "Pusula'da kalın, iyi günler dileriz" ile kapat.
- Çıktın SADECE okunacak metin olsun: başlık, madde işareti, emoji,
  "İşte brifing" gibi ön söz ya da sonda not ekleme.
''';
  }


  /// Brifinge girecek haberleri seçer.
  ///
  /// Eskiden yalnızca en yeni 6 haber alınıyordu; önem gözetilmediği için
  /// brifing çoğu zaman bir kaynağın art arda yayınladığı şirket notlarıyla
  /// doluyordu. Şimdi:
  ///   1. Önce gündem kümeleri (birden çok kaynağın işlediği olaylar),
  ///   2. sonra farklı kaynak ve kategorilerden en yeniler,
  /// toplam [take] haber; aynı kaynaktan en fazla 2.
  static List<Article> selectArticles({
    required List<Article> trending,
    required List<Article> latest,
    int take = 7,
  }) {
    final picked = <Article>[];
    final ids = <String>{};
    final perSource = <String, int>{};
    final categories = <String>{};

    bool tryAdd(Article a, {bool newCategoryOnly = false}) {
      if (picked.length >= take || ids.contains(a.id)) return false;
      final src = a.sourceName.isEmpty ? a.id : a.sourceName;
      if ((perSource[src] ?? 0) >= 2) return false;
      if (newCategoryOnly && categories.contains(a.categoryId)) return false;
      picked.add(a);
      ids.add(a.id);
      perSource[src] = (perSource[src] ?? 0) + 1;
      categories.add(a.categoryId);
      return true;
    }

    for (final a in trending.take(4)) {
      tryAdd(a);
    }
    // Önce henüz temsil edilmeyen kategoriler, sonra kalan en yeniler.
    for (final a in latest) {
      tryAdd(a, newCategoryOnly: true);
    }
    for (final a in latest) {
      tryAdd(a);
    }
    return picked;
  }

  /// Prompt'a giden özet: başlığı tekrar ediyorsa o kısım atılır (model
  /// aynı cümleyi iki kez okuyordu), uzunsa cümle sınırından kesilir
  /// (yarım cümleyi de okuyordu). Bilgi kalmıyorsa `yok`.
  static String briefingSummary(Article a, {int maxChars = 320}) {
    var body =
        (a.summary.trim().isNotEmpty ? a.summary : a.content).trim();
    final title = a.title.trim();
    String norm(String x) =>
        x.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
    if (title.isNotEmpty && norm(body).startsWith(norm(title))) {
      // Başlık kadar karakteri (noktalama farkları dahil) atla.
      var consumed = 0;
      var i = 0;
      final target = norm(title).length;
      while (i < body.length && consumed < target) {
        if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(body[i])) {
          consumed++;
        }
        i++;
      }
      body = body.substring(i).replaceFirst(RegExp(r'^[\s.,:;!?…-]+'), '');
    }
    body = body.replaceAll(RegExp(r'\s*…\s*$'), '').trim();
    if (body.length > maxChars) {
      final cut = body.substring(0, maxChars);
      final end = cut.lastIndexOf(RegExp(r'[.!?](\s|$)'));
      body = end > 80 ? cut.substring(0, end + 1) : '';
    } else if (!RegExp(r'[.!?]$').hasMatch(body)) {
      // RSS'in yarıda kestiği son cümleyi at.
      final end = body.lastIndexOf(RegExp(r'[.!?](\s|$)'));
      body = end > 0 ? body.substring(0, end + 1) : body;
    }
    return body.trim().isEmpty ? 'yok' : body.trim();
  }

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
      final summary = briefingSummary(a);
      buffer
        ..writeln('${i + 1}. [$cat] ${a.title}')
        ..writeln('   Kaynak: ${a.sourceName}')
        ..writeln('   Özet: $summary')
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

    // Cümle sonu işaretinden sonraki boşlukta böl; "7. hafta" gibi sıra
    // sayılarında (noktadan önce rakam) bölme.
    final raw = flat
        .split(RegExp(r'(?<=[^\d\s][.!?…])\s+(?=\S)'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // "Dr. Ahmet", "Prof. Ayşe" gibi kısaltmalardan sonra bölünmüşse geri
    // birleştir.
    final parts = <String>[];
    for (final p in raw) {
      if (parts.isNotEmpty && _endsWithAbbreviation(parts.last)) {
        parts[parts.length - 1] = '${parts.last} $p';
      } else {
        parts.add(p);
      }
    }

    // Kısa cümleleri bir sonrakiyle birleştir (TTS geçişleri doğal olsun),
    // tek parça [maxChars]'ı aşmasın.
    final merged = <String>[];
    for (final p in parts) {
      if (merged.isNotEmpty && merged.last.length + p.length < maxChars) {
        merged[merged.length - 1] = '${merged.last} $p';
      } else {
        merged.add(p);
      }
    }
    return merged;
  }

  static const Set<String> _abbreviations = {
    'dr', 'prof', 'doç', 'av', 'yrd', 'sn', 'st', 'no', 'vb', 'vs', 'bkz',
    'örn', 'mah', 'cad', 'sok', 'a.ş', 'ltd', 'şti',
  };

  static bool _endsWithAbbreviation(String s) {
    final m = RegExp(r'(\S+)\.$').firstMatch(s);
    if (m == null) return false;
    return _abbreviations.contains(m.group(1)!.toLowerCase());
  }

  /// AI cevabını TTS'in okuması için hafifçe temizle: madde başları, fazla
  /// boşluklar, AI'ın bazen koyduğu emojiler vb.
  String sanitizeForSpeech(String raw) {
    var s = raw
        // Model bazen ön söz ekliyor: "İşte bugünün brifingi:" satırı.
        .replaceFirst(
          // Dart'ın caseSensitive:false'u Türkçe İ'yi i ile eşlemez.
          RegExp(r'^\s*([İi]şte|[Aa]şağıda)[^\n]{0,80}:\s*\n'),
          '',
        )
        // Bağlantılar okunmasın.
        .replaceAll(RegExp(r'https?://\S+'), '')
        // "%5" → "yüzde 5", "%5,2" → "yüzde 5,2"
        .replaceAllMapped(
          RegExp(r'%\s?(\d+(?:[.,]\d+)?)'),
          (m) => 'yüzde ${m.group(1)}',
        )
        .replaceAll('₺', ' lira')
        .replaceAll(RegExp(r'\bvs\.', caseSensitive: false), 've benzeri')
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
