import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// ElevenLabs `text-to-speech` endpoint'iyle konuşan, sesli brifing için
/// MP3 üreten servis.
///
/// Endpoint: `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}`
/// Auth: `xi-api-key: {key}` (Bearer değil — ElevenLabs'e özgü header)
/// İstek gövdesi:
///
///     {
///       "text": "...",
///       "model_id": "eleven_multilingual_v2",
///       "voice_settings": {
///         "stability": 0.45,
///         "similarity_boost": 0.75,
///         "style": 0.0,
///         "use_speaker_boost": true,
///         "speed": 1.0
///       }
///     }
///
/// Yanıt: doğrudan binary MP3. JSON değil — `bodyBytes`'i çağırana
/// veririz; çağıran `audioplayers` paketi üzerinden çalar.
///
/// Fiyat (Mayıs 2026): Multilingual v2 ~\$0.30/1K karakter — brifing başına
/// ~\$0.03–0.05 arasında değişir. Turbo/Flash modelleri daha ucuz.
class ElevenLabsTtsService {
  ElevenLabsTtsService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const String _baseUrl =
      'https://api.elevenlabs.io/v1/text-to-speech';
  static const Duration _timeout = Duration(seconds: 60);

  /// Türkçe için iyi çalışan, well-known ElevenLabs sesleri.
  /// ElevenLabs Multilingual v2 tüm sesleri Türkçe destekler.
  static const List<ElevenLabsVoice> voices = [
    ElevenLabsVoice('pNInz6obpgDQGcFmaJgB', 'Adam', 'Erkek, doğal anlatıcı'),
    ElevenLabsVoice('21m00Tcm4TlvDq8ikWAM', 'Rachel', 'Kadın, sıcak, açık'),
    ElevenLabsVoice('TxGEqnHWrfWFTfGW9XjX', 'Josh', 'Erkek, derin, sakin'),
    ElevenLabsVoice('EXAVITQu4vr4xnSDxMaL', 'Bella', 'Kadın, yumuşak'),
    ElevenLabsVoice('yoZ06aMxZJJ28mfd3POQ', 'Sam', 'Erkek, genç, enerjik'),
  ];

  static const List<ElevenLabsModel> models = [
    ElevenLabsModel(
      'eleven_multilingual_v2',
      'Multilingual v2',
      'Türkçe dahil 29 dil — en kaliteli',
    ),
    ElevenLabsModel(
      'eleven_turbo_v2_5',
      'Turbo v2.5',
      'Hızlı, düşük gecikme',
    ),
    ElevenLabsModel(
      'eleven_flash_v2_5',
      'Flash v2.5',
      'En hızlı, gerçek zamanlı',
    ),
  ];

  /// Verilen metni MP3 byte'larına dönüştürür.
  ///
  /// [apiKey] kullanıcının kendi ElevenLabs anahtarı.
  /// [voiceId] [voices] listesindeki ses id'si.
  /// [modelId] [models] listesindeki model id'si.
  /// [stability] 0.0–1.0: düşük = daha değişken/dramatik, yüksek = tutarlı.
  /// [similarityBoost] 0.0–1.0: sesin orijinaline sadakati.
  /// [style] 0.0–1.0: stil amplifikasyonu (bazı seslerde belirgin).
  /// [speed] 0.7–1.2: konuşma hızı (ElevenLabs'e özgü dar aralık).
  Future<Uint8List> synthesize({
    required String apiKey,
    required String text,
    String voiceId = 'pNInz6obpgDQGcFmaJgB',
    String modelId = 'eleven_multilingual_v2',
    double stability = 0.45,
    double similarityBoost = 0.75,
    double style = 0.0,
    double speed = 1.0,
  }) async {
    if (apiKey.isEmpty) {
      throw const ElevenLabsException(
        'ElevenLabs API anahtarı boş. Ayarlar > Yapay Zeka > Sesli Okuma '
        'bölümünden girin.',
      );
    }
    if (text.trim().isEmpty) {
      throw const ElevenLabsException('Boş metin okunamaz.');
    }

    // ElevenLabs speed aralığı: 0.7–1.2
    final clampedSpeed = speed.clamp(0.7, 1.2);

    final uri = Uri.parse(
      '$_baseUrl/$voiceId?output_format=mp3_44100_128',
    );

    final response = await _client
        .post(
          uri,
          headers: {
            'xi-api-key': apiKey,
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': modelId,
            'voice_settings': {
              'stability': stability.clamp(0.0, 1.0),
              'similarity_boost': similarityBoost.clamp(0.0, 1.0),
              'style': style.clamp(0.0, 1.0),
              'use_speaker_boost': true,
              'speed': clampedSpeed,
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      // Hata gövdesi JSON formatında geliyor.
      // Format 1: { "detail": { "message": "...", "status": "..." } }
      // Format 2: { "detail": "string" }
      String message = 'ElevenLabs TTS HTTP ${response.statusCode}';
      try {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final detail = decoded['detail'];
          if (detail is Map && detail['message'] is String) {
            message =
                'HTTP ${response.statusCode}: ${detail['message']}';
          } else if (detail is String && detail.isNotEmpty) {
            message = 'HTTP ${response.statusCode}: $detail';
          }
        }
      } catch (_) {
        // Binary yanıt gelmiş ya da parse hatalı — genel mesajı koru.
      }
      throw ElevenLabsException(message, statusCode: response.statusCode);
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const ElevenLabsException('ElevenLabs TTS boş yanıt döndü.');
    }
    return bytes;
  }

  void close() => _client.close();
}

class ElevenLabsVoice {
  const ElevenLabsVoice(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

class ElevenLabsModel {
  const ElevenLabsModel(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

class ElevenLabsException implements Exception {
  const ElevenLabsException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
