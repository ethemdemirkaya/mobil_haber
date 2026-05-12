import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await initializeDateFormatting('tr_TR');
    _initialized = true;
  }

  static String relative(DateTime dateTime, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(dateTime);

    if (diff.inSeconds < 45) return 'Az önce';
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return DateFormat('d MMM yyyy', 'tr_TR').format(dateTime);
  }

  static String full(DateTime dateTime) {
    return DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(dateTime);
  }

  static String day(DateTime dateTime) {
    return DateFormat('d MMMM yyyy', 'tr_TR').format(dateTime);
  }
}
