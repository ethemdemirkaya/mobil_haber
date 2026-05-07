import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const Duration _defaultTimeout = Duration(seconds: 45);

  /// Tek bir chat-completions çağrısı yapar ve assistant cevabının
  /// metin içeriğini döner.
  ///
  /// [apiKey] runtime'da kullanıcı tarafından girilir; bu sınıf onu hiçbir
  /// yerde saklamaz (provider/preferences katmanı saklar). [model] OpenRouter
  /// formatında olmalıdır (ör. `anthropic/claude-3.5-haiku`).
  Future<String> chat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 600,
    double temperature = 0.3,
    Duration? timeout,
  }) async {
    if (apiKey.isEmpty) {
      throw const OpenRouterException(
        'API anahtarı boş — Ayarlar > Yapay Zeka\'dan girin.',
      );
    }

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
        .timeout(timeout ?? _defaultTimeout);

    final body = utf8.decode(response.bodyBytes);
    final decoded = body.isEmpty ? null : jsonDecode(body);

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

  void close() => _client.close();
}

class OpenRouterException implements Exception {
  const OpenRouterException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
