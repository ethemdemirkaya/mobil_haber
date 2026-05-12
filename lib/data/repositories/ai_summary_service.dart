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

  static const String _systemPrompt = '''
Sen bir haber özetleme asistanısın. Görevin, verilen Türkçe haber metnini
3 madde halinde, her biri tek cümlelik ve toplamda 60 kelimeyi geçmeyecek
biçimde özetlemek.

Kurallar:
- Çıktın SADECE 3 satırdır; her satır "•" işaretiyle başlar.
- Spekülasyon yapma, yorum ekleme, sadece metinde geçeni özetle.
- Sayıları ve özel isimleri koru.
- Argo veya duygu yüklü dilden kaçın, nesnel kal.
- Türkçe yanıtla.
''';

  /// Bir makaleyi 3 maddelik özet'e dönüştürür.
  ///
  /// Başlık + (varsa) tam içerik, yoksa özet metnini modele gönderir.
  Future<String> summarize({
    required Article article,
    required String apiKey,
    required String model,
  }) async {
    final source = _composeSource(article);
    final user = '''
BAŞLIK: ${article.title}

KAYNAK: ${article.sourceName.isNotEmpty ? article.sourceName : "Bilinmeyen"}

İÇERİK:
$source

Lütfen bu haberi yukarıdaki kurallara göre 3 madde halinde özetle.
''';

    return _client.chat(
      apiKey: apiKey,
      model: model,
      systemPrompt: _systemPrompt,
      userPrompt: user,
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
  }) {
    return _client.chat(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
      temperature: 0.4,
    );
  }

  String _composeSource(Article article) {
    final content = article.content.trim();
    final summary = article.summary.trim();
    if (content.isNotEmpty && content.length > summary.length) {
      // Modele çok uzun girdiler verme — token maliyeti ve hız.
      return content.length > 3500
          ? '${content.substring(0, 3500)}…'
          : content;
    }
    return summary;
  }
}
