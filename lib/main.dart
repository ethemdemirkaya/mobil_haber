import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/scheduled_briefing_service.dart';
import 'core/utils/date_formatter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DateFormatter.ensureInitialized();
  // Yerel bildirim servisi — zamanlanmış brifing tap callback'i için
  // erken init şart.
  await ScheduledBriefingService.init();
  runApp(const MobilHaberApp());
}
