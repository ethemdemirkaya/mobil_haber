import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../generated/secrets.g.dart';
import '../net/shared_http_client.dart';

/// OpenRouter API ile konuşan ham HTTP istemcisi.
///
/// OpenRouter (https://openrouter.ai/) tek bir API anahtarıyla 100+ farklı
/// AI modeline (Anthropic Claude, OpenAI GPT, Google Gemini, Meta Llama,
/// DeepSeek vb.) erişim sağlayan bir gateway'dir. API yüzeyi OpenAI'ın
/// chat-completions formatıyla **birebir uyumludur** — `model` parametresi
/// hangi modele yönlendirileceğini belirler.
///
/// Auth: `Authorization: Bearer sk-or-v1-...`
/// Endpoint: `POST /api/v1/chat/completions`
class OpenRouterClient {
  OpenRouterClient({http.Client? httpClient})
      : _client = httpClient ?? sharedHttpClient;

  final http.Client _client;

  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const Duration _defaultTimeout = Duration(seconds: 45);

  /// Build-time enjekte edilen default API anahtarı.
  ///
  /// **Önerilen kullanım — `.env.json` üzerinden:**
  ///
  ///     # 1. Şablonu kopyala
  ///     Copy-Item .env.json.example .env.json
  ///     # 2. .env.json içine anahtarını yaz (sk-or-v1-...)
  ///     # 3. VSCode'da F5 → otomatik yüklenir.
  ///     # 4. CLI: ./run.ps1
  ///
  /// **Manuel komut satırı:**
  ///
  ///     flutter run --dart-define-from-file=.env.json
  ///     flutter run --dart-define=OPENROUTER_API_KEY=sk-or-v1-xxx
  ///
  /// `.env.json` gitignored, kaynak kodda olmadığı için public repo'ya
  /// **kazara push edilmez**. CI/CD'de secret olarak saklanır. Kullanıcı
  /// Ayarlar'dan kendi anahtarını girerse o öncelikli olur (kişisel
  /// rate-limit avantajı).
  // Gradle build sırasında .env.json'dan üretilen secrets.g.dart'tan gelir.
  // Kullanıcı Ayarlar'dan kendi anahtarını girerse o önceliklidir.
  static const String defaultApiKey = kBuiltInOpenRouterApiKey;

  /// Build-time'da default key sağlanmış mı? UI tarafı buna göre "kendi
  /// keyini girmek zorunda değilsin" mesajı gösterebilir.
  static bool get hasBuiltInKey => defaultApiKey.isNotEmpty;

  /// Tek bir chat-completions çağrısı yapar ve assistant cevabının
  /// metin içeriğini döner.
  ///
  /// [apiKey] runtime'da kullanıcı tarafından girilir; bu sınıf onu hiçbir
  /// yerde saklamaz (provider/preferences katmanı saklar). [model] OpenRouter
  /// formatında olmalıdır (ör. `anthropic/claude-3.5-haiku`).
  ///
  /// [fallbackModels] verilirse, [model] geçici ya da modele özgü bir hatayla
  /// (kaldırılmış model 404, kota 429, sağlayıcı 5xx, zaman aşımı, boş yanıt)
  /// başarısız olduğunda sıradaki model denenir. Ücretsiz modeller sık
  /// kaldırılıp kotası dolduğu için gerekli; anahtar hatası (401/402) gibi
  /// her modelde tekrarlanacak hatalarda hemen durulur.
  Future<String> chat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 600,
    double temperature = 0.3,
    Duration? timeout,
    List<String> fallbackModels = const [],
  }) async {
    if (apiKey.isEmpty) {
      throw const OpenRouterException(
        'API anahtarı boş — Ayarlar > Yapay Zeka\'dan girin.',
      );
    }
    final chain = [model, ...fallbackModels.where((m) => m != model)];
    OpenRouterException? lastError;
    for (final m in chain) {
      try {
        return await _chatOnce(
          apiKey: apiKey,
          model: m,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
          timeout: timeout ?? _defaultTimeout,
        );
      } on OpenRouterException catch (e) {
        if (!_shouldTryNextModel(e)) rethrow;
        lastError = e;
      } on TimeoutException {
        lastError = OpenRouterException('$m yanıt vermedi (zaman aşımı).');
      }
    }
    throw lastError!;
  }

  /// Başka bir modelde düzelebilecek hatalar. `statusCode` null olanlar
  /// yanıt biçimi/boş içerik hatalarıdır — modele özgüdür.
  static bool _shouldTryNextModel(OpenRouterException e) {
    final code = e.statusCode;
    return code == null ||
        const {404, 408, 429, 500, 502, 503, 504}.contains(code);
  }

  Future<String> _chatOnce({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
    required Duration timeout,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json; charset=utf-8',
            // OpenRouter "App ranking" özelliği için bu iki header'ı tavsiye
            // ediyor — kullanıcı dashboard'unda hangi uygulamadan istek
            // geldiğini görebilsin.
            'HTTP-Referer': 'https://github.com/ethemdemirkaya/mobil_haber',
            'X-Title': 'mobil_haber',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'max_tokens': maxTokens,
            'temperature': temperature,
          }),
        )
        .timeout(timeout);

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      // Ağ geçidi HTML hata sayfası döndürmüş olabilir.
      decoded = null;
    }

    if (response.statusCode != 200) {
      throw OpenRouterException(
        _extractErrorMessage(decoded, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map) {
      throw const OpenRouterException(
        'Beklenmeyen yanıt formatı (Map değil).',
      );
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const OpenRouterException(
        'Yanıt boş — model cevap üretmedi.',
      );
    }
    final message = choices.first['message'];
    if (message is! Map) {
      throw const OpenRouterException(
        'Yanıt formatı tanınmadı (message yok).',
      );
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const OpenRouterException(
        'Model boş içerik döndürdü.',
      );
    }
    return content.trim();
  }

  /// Verilen API anahtarının geçerli olup olmadığını kısa bir "ping" ile
  /// doğrular. Settings ekranındaki "Bağlantıyı test et" butonu için.
  Future<void> testConnection({
    required String apiKey,
    required String model,
  }) async {
    await chat(
      apiKey: apiKey,
      model: model,
      systemPrompt: 'You are a connectivity probe. Reply with the word OK.',
      userPrompt: 'ping',
      maxTokens: 8,
      temperature: 0,
      timeout: const Duration(seconds: 20),
    );
  }

  String _extractErrorMessage(dynamic decoded, int status) {
    // Özel durum: 429 — provider rate-limit. Kullanıcıya ne yapacağını söyle.
    if (status == 429) {
      String detail = '';
      if (decoded is Map) {
        final err = decoded['error'];
        final m = (err is Map ? err['message'] : decoded['message']);
        if (m is String && m.isNotEmpty) detail = '\n$m';
      }
      return '429 — İstek limiti aşıldı.$detail\n\n'
          'Ücretsiz modeller günlük kota veya dakika başına istek sınırına '
          'sahiptir. Birkaç dakika bekleyip tekrar deneyin ya da '
          'Ayarlar > Yapay Zeka > Model bölümünden farklı bir model seçin.';
    }
    if (decoded is Map) {
      final err = decoded['error'];
      if (err is Map) {
        final m = err['message'];
        if (m is String && m.isNotEmpty) return 'HTTP $status: $m';
      }
      final m = decoded['message'];
      if (m is String && m.isNotEmpty) return 'HTTP $status: $m';
    }
    return 'OpenRouter HTTP $status';
  }

  void close() => closeIfOwned(_client);
}

class OpenRouterException implements Exception {
  const OpenRouterException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
