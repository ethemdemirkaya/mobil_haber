import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_init;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/category.dart';

/// Bir zamanlanmış brifing girdisi: günün belirli saatinde belirli bir
/// kategoride brifing bildirimi gönder.
///
/// Bildirim'e dokununca uygulama açılır → DailyBriefingScreen kategoriyle
/// önceden seçili olarak gelir → AI brifing otomatik üretilir + okunur.
///
/// Veri sadece local — sunucu/Firebase'e ihtiyaç yok. Cihaz uyandığında
/// local notification çıkar; uygulama açılırsa kategoriye göre brifing
/// üretilir.
class ScheduledBriefing {
  const ScheduledBriefing({
    required this.id,
    required this.hour,
    required this.minute,
    required this.categoryId,
    this.daysOfWeek = const {1, 2, 3, 4, 5, 6, 7},
    this.enabled = true,
  });

  /// Notification id (1..N). flutter_local_notifications int id ister.
  final int id;
  final int hour; // 0-23
  final int minute; // 0-59

  /// `NewsCategory.id` veya 'all' (genel gündem).
  final String categoryId;

  /// 1=Pazartesi … 7=Pazar (DateTime weekday convention).
  final Set<int> daysOfWeek;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'categoryId': categoryId,
        'daysOfWeek': daysOfWeek.toList(),
        'enabled': enabled,
      };

  factory ScheduledBriefing.fromJson(Map<String, dynamic> json) {
    return ScheduledBriefing(
      id: (json['id'] as num).toInt(),
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      categoryId: json['categoryId']?.toString() ?? 'all',
      daysOfWeek: (json['daysOfWeek'] as List?)
              ?.whereType<num>()
              .map((n) => n.toInt())
              .toSet() ??
          const {1, 2, 3, 4, 5, 6, 7},
      enabled: json['enabled'] != false,
    );
  }

  ScheduledBriefing copyWith({
    int? hour,
    int? minute,
    String? categoryId,
    Set<int>? daysOfWeek,
    bool? enabled,
  }) {
    return ScheduledBriefing(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      categoryId: categoryId ?? this.categoryId,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      enabled: enabled ?? this.enabled,
    );
  }

  String get title {
    final cat = NewsCategory.byId(categoryId);
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return categoryId == 'all'
        ? 'Genel brifing — $timeStr'
        : '${cat.name} brifingi — $timeStr';
  }

  String get daysLabel {
    if (daysOfWeek.length == 7) return 'Her gün';
    if (daysOfWeek.containsAll({1, 2, 3, 4, 5}) && daysOfWeek.length == 5) {
      return 'Hafta içi';
    }
    if (daysOfWeek.containsAll({6, 7}) && daysOfWeek.length == 2) {
      return 'Hafta sonu';
    }
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final sorted = daysOfWeek.toList()..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }
}

/// Zamanlanmış brifing kayıtlarını yöneten servis. UI provider değil
/// (ChangeNotifier yok); UI tarafı statik metodlarla erişir, kayıt
/// listesi shared_prefs'te tutulur.
class ScheduledBriefingService {
  ScheduledBriefingService._();

  static const String _prefsKey = 'pref_scheduled_briefings';
  static const String _channelId = 'pusula_briefing_channel';
  static const String _channelName = 'Pusula Brifing Bildirimleri';
  static const String _channelDesc =
      'Kullanıcının ayarladığı zamanlanmış sesli brifing bildirimleri.';

  /// Bildirim'e dokunulduğunda payload'ı tetikleyen yönlendirme stream'i.
  /// UI bunu dinleyip DailyBriefingScreen'i kategoriyle açar.
  static final ValueNotifier<String?> tappedPayload =
      ValueNotifier<String?>(null);

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Uygulama açıldığında main()'dan çağrılır. Bildirim tap callback
  /// kayıt eder + zaman dilimini set eder.
  static Future<void> init() async {
    if (_initialized) return;
    tz_init.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {/* default UTC kalsın */}

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final p = response.payload;
        if (p != null && p.isNotEmpty) {
          tappedPayload.value = p;
        }
      },
    );

    // Android 13+ ve iOS için izin iste.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// Kayıtlı tüm brifingleri döner.
  static Future<List<ScheduledBriefing>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => ScheduledBriefing.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Yeni brifing ekle (id otomatik) veya mevcut güncelle.
  static Future<ScheduledBriefing> save(ScheduledBriefing item) async {
    final list = (await all()).toList();
    final idx = list.indexWhere((x) => x.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    await _persist(list);
    if (item.enabled) {
      await _schedule(item);
    } else {
      await _plugin.cancel(item.id);
    }
    return item;
  }

  /// Yeni id üret — basit max+1.
  static Future<int> nextId() async {
    final list = await all();
    if (list.isEmpty) return 1;
    return list.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Bir kayıt sil + bildirimi iptal et.
  static Future<void> delete(int id) async {
    final list = (await all()).where((x) => x.id != id).toList();
    await _persist(list);
    await _plugin.cancel(id);
  }

  /// Bildirim'i kapat ama kayıtta tut (kullanıcı sonra açabilir).
  static Future<void> setEnabled(int id, bool enabled) async {
    final list = await all();
    final idx = list.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final updated = list[idx].copyWith(enabled: enabled);
    final newList = List<ScheduledBriefing>.of(list)..[idx] = updated;
    await _persist(newList);
    if (enabled) {
      await _schedule(updated);
    } else {
      await _plugin.cancel(id);
    }
  }

  /// Tüm kayıtları yeniden zamanlar — uygulama yeniden açılınca veya
  /// timezone değişince çağrılır.
  static Future<void> rescheduleAll() async {
    final list = await all();
    for (final s in list) {
      if (s.enabled) await _schedule(s);
    }
  }

  static Future<void> _persist(List<ScheduledBriefing> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  /// Tek bir brifingi haftalık tekrarla zamanlar. flutter_local_notifications
  /// `weekly` doğrudan desteklemediği için her gün için ayrı id ile
  /// (id*10 + gün) zamanla — alternatif: matchDateTimeComponents:
  /// DateTimeComponents.dayOfWeekAndTime ile her gün id'sine ait tek
  /// kayıt + UI tarafında istediği günü filtreleme. Biz daha pratik yolu
  /// seçtik: tek id, daily tekrar; UI gerektiğinde gün filtresi yapar.
  ///
  /// MVP için: günde bir bildirim (ilk eşleşen gün), sonraki güne
  /// sürünür. matchDateTimeComponents.time ile günde bir tekrar.
  static Future<void> _schedule(ScheduledBriefing s) async {
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      s.hour,
      s.minute,
    );
    if (first.isBefore(now)) {
      first = first.add(const Duration(days: 1));
    }

    final cat = NewsCategory.byId(s.categoryId);
    final body = s.categoryId == 'all'
        ? 'Bugünün gündemi hazır. Açıp dinleyebilirsiniz.'
        : '${cat.name} brifingi seni bekliyor.';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const iosDetails = DarwinNotificationDetails();
    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        s.id,
        s.title,
        body,
        first,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // Günde aynı saatte tekrar et. Gün-of-week filtresi UI tarafında
        // (kullanıcı bildirim gelince açar, brifing yine üretilir; yanlış
        // günde gelmesi MVP için kabul edilebilir; ileride per-gün ayrı
        // id ile genişletilebilir).
        matchDateTimeComponents: DateTimeComponents.time,
        payload: s.categoryId,
      );
      debugPrint(
        '[Pusula][Sched] ${s.title} → ${first.toIso8601String()}',
      );
    } catch (e) {
      debugPrint('[Pusula][Sched] zonedSchedule hata: $e');
    }
  }
}
