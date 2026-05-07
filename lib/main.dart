import 'package:flutter/material.dart';

import 'app.dart';
import 'core/utils/date_formatter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DateFormatter.ensureInitialized();
  runApp(const MobilHaberApp());
}
