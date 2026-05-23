import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Microsoft Edge'in ücretsiz TTS servisine WebSocket üzerinden bağlanan
/// servis. API anahtarı gerekmez — Edge tarayıcısının "Sesli Oku" özelliği
/// ile aynı altyapıyı kullanır.
///
/// Desteklenen Türkçe sesler: tr-TR-EmelNeural (kadın), tr-TR-AhmetNeural (erkek)
/// Çıktı: audio-24khz-48kbitrate-mono-mp3 (Uint8List)
///
/// Protokol (reverse-engineered — rany2/edge-tts projesi referans alındı):
/// 1. WebSocket bağlantısı kurulur (Sec-MS-GEC token ile)
/// 2. speech.config JSON mesajı gönderilir
/// 3. SSML metin mesajı gönderilir
/// 4. Sunucu binary MP3 chunk'ları döner, `Path:turn.end` ile biter
class EdgeTtsService {
  static const String _trustedToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _chromiumVer = '143.0.3650.75';
  static const String _wssBase =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const Duration _timeout = Duration(seconds: 30);

  // ─── Sesler ───────────────────────────────────────────────────────────────

  static const List<EdgeTtsVoice> voices = [
    EdgeTtsVoice('tr-TR-EmelNeural', 'Emel', 'Kadın · doğal Türkçe'),
    EdgeTtsVoice('tr-TR-AhmetNeural', 'Ahmet', 'Erkek · doğal Türkçe'),
  ];

  // ─── Yardımcı metodlar ────────────────────────────────────────────────────

  /// Sec-MS-GEC token'ı: Windows FILETIME (3000 tick'e yuvarlanmış) +
  /// TrustedClientToken'ın SHA-256 özeti (büyük harf).
  static String _buildGec() {
    // Dart: ms × 10 000 = 100-nanosaniyelik tick cinsinden Unix zamanı.
    // Windows FILETIME başlangıcı (1601-01-01) → Unix epoch (1970-01-01) farkı
    // = 116 444 736 000 000 000 tick.
    const int winOffset = 116444736000000000;
    final ticks = DateTime.now().millisecondsSinceEpoch * 10000 + winOffset;
    final rounded = ticks - (ticks % 3000);
    final raw = '$rounded$_trustedToken';
    return sha256.convert(utf8.encode(raw)).toString().toUpperCase();
  }

  static String _uuid() {
    final r = Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _timestamp() =>
      '${DateTime.now().toUtc().toIso8601String().substring(0, 23)}Z';

  static String _ssml({
    required String text,
    required String voice,
    int ratePct = 0,
    int pitchHz = 0,
  }) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final rate = ratePct >= 0 ? '+${ratePct}%' : '$ratePct%';
    final pitch = pitchHz >= 0 ? '+${pitchHz}Hz' : '${pitchHz}Hz';
    return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis'"
        " xml:lang='tr-TR'><voice name='$voice'>"
        "<prosody pitch='$pitch' rate='$rate' volume='+0%'>$escaped</prosody>"
        "</voice></speak>";
  }

  // ─── Ana API ──────────────────────────────────────────────────────────────

  /// Metni MP3 byte dizisine dönüştürür.
  ///
  /// [voice]   → Türkçe varsayılan: 'tr-TR-EmelNeural'
  /// [ratePct] → konuşma hızı farkı (-50..+100). 0 = normal.
  Future<Uint8List> synthesize({
    required String text,
    String voice = 'tr-TR-EmelNeural',
    int ratePct = 0,
  }) async {
    if (text.trim().isEmpty) {
      throw const EdgeTtsException('Boş metin okunamaz.');
    }

    final connId = _uuid();
    final gec = _buildGec();
    final url = '$_wssBase'
        '?TrustedClientToken=$_trustedToken'
        '&ConnectionId=$connId'
        '&Sec-MS-GEC=$gec'
        '&Sec-MS-GEC-Version=1-$_chromiumVer';

    WebSocket ws;
    try {
      ws = await WebSocket.connect(
        url,
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/$_chromiumVer Safari/537.36 Edg/$_chromiumVer',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(_timeout);
    } on SocketException catch (e) {
      throw EdgeTtsException('Edge TTS bağlantı hatası: $e');
    } on TimeoutException {
      throw const EdgeTtsException('Edge TTS bağlantı zaman aşımı.');
    }

    try {
      // 1. speech.config
      ws.add(
        'X-Timestamp:${_timestamp()}\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n'
        '{"context":{"synthesis":{"audio":{"metadataoptions":'
        '{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},'
        '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}',
      );

      // 2. SSML
      final reqId = _uuid();
      ws.add(
        'X-RequestId:$reqId\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'X-Timestamp:${_timestamp()}\r\n'
        'Path:ssml\r\n\r\n'
        '${_ssml(text: text, voice: voice, ratePct: ratePct)}',
      );

      // 3. Ses chunk'larını topla
      final chunks = <Uint8List>[];
      final done = Completer<void>();

      ws.listen(
        (dynamic msg) {
          if (msg is String) {
            if (msg.contains('Path:turn.end') && !done.isCompleted) {
              done.complete();
            }
          } else if (msg is List<int>) {
            final bytes = Uint8List.fromList(msg);
            if (bytes.length < 2) return;
            // İlk 2 byte → big-endian header uzunluğu
            final hLen = (bytes[0] << 8) | bytes[1];
            if (bytes.length < 2 + hLen) return;
            final header =
                utf8.decode(bytes.sublist(2, 2 + hLen), allowMalformed: true);
            if (header.contains('audio/mpeg') || header.contains('audio/')) {
              final audio = bytes.sublist(2 + hLen);
              if (audio.isNotEmpty) chunks.add(audio);
            }
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (dynamic err) {
          if (!done.isCompleted) {
            done.completeError(EdgeTtsException('Edge TTS stream hatası: $err'));
          }
        },
        cancelOnError: true,
      );

      await done.future.timeout(
        _timeout,
        onTimeout: () {
          throw const EdgeTtsException('Edge TTS yanıt zaman aşımı.');
        },
      );

      if (chunks.isEmpty) {
        throw const EdgeTtsException('Edge TTS ses verisi gelmedi.');
      }

      final total = chunks.fold<int>(0, (s, c) => s + c.length);
      final result = Uint8List(total);
      var off = 0;
      for (final c in chunks) {
        result.setRange(off, off + c.length, c);
        off += c.length;
      }
      return result;
    } finally {
      await ws.close();
    }
  }
}

class EdgeTtsVoice {
  const EdgeTtsVoice(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

class EdgeTtsException implements Exception {
  const EdgeTtsException(this.message);
  final String message;
  @override
  String toString() => message;
}
