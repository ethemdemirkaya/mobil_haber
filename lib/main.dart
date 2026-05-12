import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/scheduled_briefing_service.dart';
import 'core/tts/audio_session_setup.dart';
import 'core/tts/briefing_audio_handler.dart';
import 'core/utils/date_formatter.dart';

/// Tek bir init'in hang etmesi tüm app'i splash'a kilitliyor — her birini
/// kısa bir timeout'la sarıyoruz. Bir tanesi yavaş veya çakılırsa
/// uygulamaya devam edip user'ın haberlere erişmesine izin veriyoruz.
Future<void> _safeInit(String name, Future<void> Function() op,
    {Duration timeout = const Duration(seconds: 6)}) async {
  try {
    await op().timeout(timeout, onTimeout: () {
      debugPrint('[Pusula][init] $name timeout (${timeout.inSeconds}s) — skip');
    });
  } catch (e) {
    debugPrint('[Pusula][init] $name hata: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DateFormatter.ensureInitialized();

  // Tüm yan-servis init'leri timeout'lu — bir tanesi takılsa bile splash'tan
  // çıkıp ana ekrana geçilir. Haber çekimi tamamen ayrı yolda çalışıyor.
  // İlk kurulumda flutter_cache_manager SQLite DB'sini widget tree kurulmadan
  // önce hazır hale getirir — aksi hâlde ilk açılışta resimler yüklenemez.
  await _safeInit('ImageCacheManager',
      () async => DefaultCacheManager().getFileFromCache('__warmup__'));

  await _safeInit('AudioSessionSetup', AudioSessionSetup.configure);
  await _safeInit('BriefingAudioHandler', BriefingAudioHandler.bootstrap);
  await _safeInit('ScheduledBriefingService', ScheduledBriefingService.init);
  await _safeInit('PushNotificationService', () async {
    await PushNotificationService.init(
      localNotifs: FlutterLocalNotificationsPlugin(),
    );
  }, timeout: const Duration(seconds: 8));

  runApp(const MobilHaberApp());
}
