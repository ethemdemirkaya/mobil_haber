import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// OpenAI TTS'ten alınan MP3 byte'larını disk'te cache'leyen helper.
///
/// Cache anahtarı: `sha256(text + voice + model + speed)` — aynı brifing
/// metnini aynı parametrelerle tekrar istediğimizde API'ye gitmez,
/// MP3 doğrudan disk'ten okunur (saniyeler yerine milisaniyeler).
///
/// Konum: app documents directory altında `pusula_tts_cache/`.
/// Otomatik temizlik: bu sınıf yapmaz; kullanıcı Ayarlar > Yapay Zeka >
/// Cache temizle ile silebilir, ya da `clear()` çağrılır.
class BriefingAudioCache {
  BriefingAudioCache._();

  static const String _dirName = 'pusula_tts_cache';
  static Directory? _cacheDir;
  static final int _ttlDays = 30; // 30 gün üstü dosyalar atılabilir.

  /// Cache klasörünü hazırlar (lazy). Birden fazla çağrıda race olmasın
  /// diye basit memoize.
  static Future<Directory> _ensureDir() async {
    final cached = _cacheDir;
    if (cached != null && await cached.exists()) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  static String _cacheKey({
    required String text,
    required String voice,
    required String model,
    required double speed,
  }) {
    // Hızı 2 ondalığa yuvarla — slider hassasiyetinden gelen 0.50000001
    // gibi farklılıkların aynı dosyayı kullanmasını sağlar.
    final speedKey = speed.toStringAsFixed(2);
    final raw = '$text|$voice|$model|$speedKey';
    final hash = sha256.convert(utf8.encode(raw));
    return hash.toString();
  }

  /// Bu kombinasyon için cache'lenmiş MP3 var mı?
  static Future<File?> find({
    required String text,
    required String voice,
    required String model,
    required double speed,
  }) async {
    try {
      final dir = await _ensureDir();
      final key = _cacheKey(
        text: text,
        voice: voice,
        model: model,
        speed: speed,
      );
      final file = File('${dir.path}/$key.mp3');
      if (await file.exists() && await file.length() > 0) return file;
      return null;
    } catch (e) {
      debugPrint('[Pusula][AudioCache] find error: $e');
      return null;
    }
  }

  /// Yeni bir MP3'ü cache'e yazar. İçerik 5 MB üstüyse yine yazar — TTS
  /// MP3'leri tipik olarak <2 MB.
  static Future<File?> store({
    required String text,
    required String voice,
    required String model,
    required double speed,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await _ensureDir();
      final key = _cacheKey(
        text: text,
        voice: voice,
        model: model,
        speed: speed,
      );
      final file = File('${dir.path}/$key.mp3');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('[Pusula][AudioCache] store error: $e');
      return null;
    }
  }

  /// Cache klasörünün toplam boyutunu hesaplar (UI için "78 dosya, 4.2 MB").
  static Future<CacheStats> stats() async {
    try {
      final dir = await _ensureDir();
      var bytes = 0;
      var count = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          count++;
          bytes += await entity.length();
        }
      }
      return CacheStats(count: count, bytes: bytes);
    } catch (e) {
      debugPrint('[Pusula][AudioCache] stats error: $e');
      return const CacheStats(count: 0, bytes: 0);
    }
  }

  /// Tüm cache'lenmiş MP3'leri siler. Geri dönüşü temizlenen dosya sayısı.
  static Future<int> clear() async {
    try {
      final dir = await _ensureDir();
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          try {
            await entity.delete();
            removed++;
          } catch (_) {}
        }
      }
      return removed;
    } catch (e) {
      debugPrint('[Pusula][AudioCache] clear error: $e');
      return 0;
    }
  }

  /// TTL'den eski olanları sil — periyodik temizlik için (şu an manuel
  /// çağrı; ileride app start'ta tetiklenebilir).
  static Future<int> evictOlderThan({int? days}) async {
    final cutoffDays = days ?? _ttlDays;
    try {
      final dir = await _ensureDir();
      final threshold =
          DateTime.now().subtract(Duration(days: cutoffDays));
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(threshold)) {
            try {
              await entity.delete();
              removed++;
            } catch (_) {}
          }
        }
      }
      return removed;
    } catch (e) {
      debugPrint('[Pusula][AudioCache] evictOlderThan error: $e');
      return 0;
    }
  }
}

class CacheStats {
  const CacheStats({required this.count, required this.bytes});
  final int count;
  final int bytes;

  String get humanSize {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
