import '../../core/ai/openrouter_client.dart';
import '../models/article.dart';

/// Yapay zeka tabanlı haber özetleme servisi.
///
/// `OpenRouterClient`'ı sarmalayıp belirli bir prompt template'i ile çağırır.
/// Cache responsibility provider katmanına bırakılır — bu sınıf yalnızca
/// "verilen makaleyi özetle" işine odaklanır.
class AiSummaryService {
  AiSummaryService({OpenRouterClient? client})
      : _client = client ?? OpenRouterClient();

  final OpenRouterClient _client;

  static String _systemPrompt(int bullets) => '''
Sen bir haber özetleme asistanısın. Görevin, verilen Türkçe haber metnini
$bullets madde halinde, her biri tek cümlelik biçimde özetlemek.

Kurallar:
- Çıktın SADECE $bullets satırdır; her satır "•" işaretiyle başlar.
- YALNIZCA verilen metinde açıkça yazan bilgiyi kullan. Metinde olmayan
  hiçbir isim, sayı, tarih, neden veya sonuç ekleme; genel bilgini katma.
- Metin $bullets ayrı bilgi içermiyorsa daha az madde yaz; madde uydurma.
- Spekülasyon yapma, yorum ekleme.
- Sayıları ve özel isimleri olduğu gibi koru.
- Argo veya duygu yüklü dilden kaçın, nesnel kal.
- Türkçe yanıtla.
''';

  /// Özetlenecek metin bu uzunluğun altındaysa özet üretilmez — tek
  /// cümlelik RSS açıklamasını "özetlemek" ya tekrar ya da uydurma üretir.
  static const int minSourceChars = 300;

  /// [sourceText] (makalenin gövdesi; RSS içeriği ya da sayfadan çıkarılan
  /// metin) üzerinden madde madde özet üretir.
  Future<String> summarize({
    required Article article,
    required String sourceText,
    required String apiKey,
    required String model,
    List<String> fallbackModels = const [],
  }) async {
    final text = sourceText.length > 3500
        ? '${sourceText.substring(0, 3500)}…'
        : sourceText;
    final bullets = text.length < 1500 ? 2 : 3;
    final user = '''
BAŞLIK: ${article.title}

KAYNAK: ${article.sourceName.isNotEmpty ? article.sourceName : "Bilinmeyen"}

İÇERİK:
$text

Lütfen bu haberi yukarıdaki kurallara göre en fazla $bullets madde halinde
özetle.
''';

    return _client.chat(
      apiKey: apiKey,
      model: model,
      systemPrompt: _systemPrompt(bullets),
      userPrompt: user,
      temperature: 0.1,
      fallbackModels: fallbackModels,
    );
  }

  Future<void> testConnection({
    required String apiKey,
    required String model,
  }) =>
      _client.testConnection(apiKey: apiKey, model: model);

  /// Serbest prompt — özet dışındaki AI ihtiyaçları için (sesli brifing,
  /// kategori başlığı üretme vb.). Sistem ve kullanıcı prompt'unu çağıran
  /// belirler.
  Future<String> generate({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1000,
    double temperature = 0.4,
    List<String> fallbackModels = const [],
  }) {
    return _client.chat(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
      fallbackModels: fallbackModels,
    );
  }
}
