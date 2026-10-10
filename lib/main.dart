import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/scheduled_briefing_service.dart';
import 'core/app_startup.dart';
import 'core/utils/date_formatter.dart';

/// Tek bir init'in hang etmesi tüm app'i splash'a kilitliyor — her birini
/// kısa bir timeout'la sarıyoruz. Bir tanesi yavaş veya çakılırsa
/// uygulamaya devam edip user'ın haberlere erişmesine izin veriyoruz.
Future<void> _safeInit(
  String name,
  Future<void> Function() op, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await op().timeout(
      timeout,
      onTimeout: () {
        debugPrint(
          '[Pusula][init] $name timeout (${timeout.inSeconds}s) — skip',
        );
      },
    );
  } catch (e) {
    debugPrint('[Pusula][init] $name hata: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DateFormatter.ensureInitialized();

  runApp(const MobilHaberApp());

  // Bildirim izni isteyen init'ler hem bağlı bir activity'ye ihtiyaç duyar
  // hem de kullanıcının izin penceresine yanıt vermesini bekler. runApp'tan
  // önce çalıştıklarında activity henüz yoktu ("Context null", "Unable to
  // detect current Android Activity") ve açılışı 14 sn'ye kadar
  // bekletiyorlardı. İlk kareden sonra, birbirini beklemeden çalışırlar.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AppStartup.prepareAudio());
    unawaited(
      _safeInit(
        'ScheduledBriefingService',
        ScheduledBriefingService.init,
        timeout: const Duration(seconds: 30),
      ),
    );
    unawaited(
      _safeInit('PushNotificationService', () async {
        await PushNotificationService.init(
          localNotifs: FlutterLocalNotificationsPlugin(),
        );
      }, timeout: const Duration(seconds: 30)),
    );
  });
}
