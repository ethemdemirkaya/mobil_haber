import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// OpenAI'ın `audio/speech` endpoint'iyle konuşan, sesli brifing için
/// MP3 üreten servis.
///
/// Endpoint: `POST https://api.openai.com/v1/audio/speech`
/// Auth: `Authorization: Bearer sk-...`
/// İstek gövdesi:
///
///     { "model": "tts-1", "voice": "alloy", "input": "metin",
///       "format": "mp3" }
///
/// Yanıt: doğrudan binary MP3. JSON değil — `bodyBytes`'i çağırana
/// veririz; çağıran `audioplayers` paketi üzerinden çalar.
///
/// Maliyet (Mayıs 2026): tts-1 \$15/1M karakter ≈ 1000 karakterlik bir
/// brifing \$0.015. Yüksek kalite isteyen kullanıcı içindir; varsayılan
/// hala sistem TTS (ücretsiz).
class OpenAiTtsService {
  OpenAiTtsService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const String _endpoint = 'https://api.openai.com/v1/audio/speech';
  static const Duration _timeout = Duration(seconds: 45);

  /// OpenAI TTS desteklenen ses listesi (Mayıs 2026 itibariyle).
  /// Türkçe için en doğal sonucu `nova` ve `shimmer` veriyor (multilingual).
  static const List<OpenAiVoice> voices = [
    OpenAiVoice('alloy', 'Alloy', 'Nötr, dengeli'),
    OpenAiVoice('echo', 'Echo', 'Erkek, sakin'),
    OpenAiVoice('fable', 'Fable', 'Hikaye anlatıcı tonu'),
    OpenAiVoice('onyx', 'Onyx', 'Erkek, derin'),
    OpenAiVoice('nova', 'Nova', 'Kadın, parlak — Türkçe için iyi'),
    OpenAiVoice('shimmer', 'Shimmer', 'Kadın, sıcak — Türkçe için iyi'),
  ];

  static const List<OpenAiTtsModel> models = [
    OpenAiTtsModel('tts-1', 'TTS-1', 'Hızlı, daha ucuz (\$15/1M char)'),
    OpenAiTtsModel('tts-1-hd', 'TTS-1 HD', 'Daha kaliteli (\$30/1M char)'),
  ];

  /// Verilen metni MP3 byte'larına dönüştürür.
  ///
  /// [apiKey] kullanıcının kendi OpenAI anahtarı (ayrı, OpenRouter
  /// anahtarından bağımsız).
  /// [voice] presetlerden biri (alloy/echo/...).
  /// [speed] 0.25 - 4.0; 1.0 normal hız.
  Future<Uint8List> synthesize({
    required String apiKey,
    required String text,
    String voice = 'nova',
    String model = 'tts-1',
    double speed = 1.0,
  }) async {
    if (apiKey.isEmpty) {
      throw const OpenAiTtsException(
        'OpenAI API anahtarı boş. Ayarlar > Yapay Zeka > Sesli Okuma '
        'kalitesi bölümünden girin.',
      );
    }
    if (text.trim().isEmpty) {
      throw const OpenAiTtsException('Boş metin okunamaz.');
    }
    final clamped = speed.clamp(0.25, 4.0);

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'model': model,
            'voice': voice,
            'input': text,
            'format': 'mp3',
            'speed': clamped,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      // Hata gövdesi JSON formatında geliyor.
      String message = 'OpenAI TTS HTTP ${response.statusCode}';
      try {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] is Map) {
          final m = decoded['error']['message'];
          if (m is String && m.isNotEmpty) message = 'HTTP ${response.statusCode}: $m';
        }
      } catch (_) {/* binary olabiliyor */}
      throw OpenAiTtsException(message, statusCode: response.statusCode);
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const OpenAiTtsException('OpenAI TTS boş yanıt döndü.');
    }
    return bytes;
  }

  void close() => _client.close();
}

class OpenAiVoice {
  const OpenAiVoice(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

class OpenAiTtsModel {
  const OpenAiTtsModel(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

class OpenAiTtsException implements Exception {
  const OpenAiTtsException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
