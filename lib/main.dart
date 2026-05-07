import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/scheduled_briefing_service.dart';
import 'core/tts/audio_session_setup.dart';
import 'core/utils/date_formatter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DateFormatter.ensureInitialized();
  // Sesli brifing arka planda da çalışsın diye iOS/Android audio session
  // ayarı (speech preset). Bu olmadan iOS'ta ekran kilitlenince ses durur.
  await AudioSessionSetup.configure();
  // Yerel bildirim servisi — zamanlanmış brifing tap callback'i için
  // erken init şart.
  await ScheduledBriefingService.init();
  // Firebase Cloud Messaging — config dosyaları yoksa sessizce skip eder.
  // Setup adımları için: docs/FIREBASE_SETUP.md
  await PushNotificationService.init(
    localNotifs: FlutterLocalNotificationsPlugin(),
  );
  runApp(const MobilHaberApp());
}
