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

  /// Yeni brifing ekle (id otomatik) veya mevcut güncelle. Önceki
  /// schedule'lar iptal edilir, yeni gün setine göre yeniden zamanlanır.
  static Future<ScheduledBriefing> save(ScheduledBriefing item) async {
    final list = (await all()).toList();
    final idx = list.indexWhere((x) => x.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    await _persist(list);
    // Eski day-of-week id'lerini de sil (ID şeması değişmiş olabilir).
    await _cancelAllForBriefing(item.id);
    if (item.enabled) {
      await _schedule(item);
    }
    return item;
  }

  /// Bir brifing için tüm gün-id'lerini iptal eder.
  /// Şema: notif id = baseId * 10 + dayOfWeek (1..7).
  static Future<void> _cancelAllForBriefing(int baseId) async {
    for (var d = 1; d <= 7; d++) {
      try {
        await _plugin.cancel(baseId * 10 + d);
      } catch (_) {/* yoksa bir şey olmaz */}
    }
  }

  /// Yeni id üret — basit max+1.
  static Future<int> nextId() async {
    final list = await all();
    if (list.isEmpty) return 1;
    return list.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Bir kayıt sil + tüm gün-id'lerini iptal et.
  static Future<void> delete(int id) async {
    final list = (await all()).where((x) => x.id != id).toList();
    await _persist(list);
    await _cancelAllForBriefing(id);
  }

  /// Bildirim'i kapat ama kayıtta tut (kullanıcı sonra açabilir).
  static Future<void> setEnabled(int id, bool enabled) async {
    final list = await all();
    final idx = list.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final updated = list[idx].copyWith(enabled: enabled);
    final newList = List<ScheduledBriefing>.of(list)..[idx] = updated;
    await _persist(newList);
    await _cancelAllForBriefing(id);
    if (enabled) {
      await _schedule(updated);
    }
  }

  /// Tüm kayıtları yeniden zamanlar — uygulama yeniden açılınca veya
  /// timezone değişince çağrılır.
  static Future<void> rescheduleAll() async {
    final list = await all();
    for (final s in list) {
      await _cancelAllForBriefing(s.id);
      if (s.enabled) await _schedule(s);
    }
  }

  static Future<void> _persist(List<ScheduledBriefing> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  /// Brifingi seçili günler için zamanlar. Her gün için ayrı bildirim id
  /// (`baseId * 10 + dayOfWeek`) + `matchDateTimeComponents.dayOfWeekAndTime`
  /// kombinasyonu kullanılır — bu, bildirimi yalnızca o gün+saat eşleşince
  /// haftalık olarak tekrarlar.
  ///
  /// Örnek:
  ///   baseId = 5, daysOfWeek = {1, 2, 3, 4, 5} (hafta içi)
  ///   → 5 ayrı bildirim: id 51 (Pzt), 52 (Sal), 53 (Çar), 54 (Per), 55 (Cum)
  ///   Her biri sadece kendi günü 07:00'da çıkar, haftalık tekrar eder.
  static Future<void> _schedule(ScheduledBriefing s) async {
    final now = tz.TZDateTime.now(tz.local);
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

    // Boş günlerde hiç bildirim oluşturulmaz.
    if (s.daysOfWeek.isEmpty) {
      debugPrint('[Pusula][Sched] daysOfWeek boş → skip ${s.title}');
      return;
    }

    for (final dayOfWeek in s.daysOfWeek) {
      final notifId = s.id * 10 + dayOfWeek;
      final firstFire = _nextOccurrenceOfDay(
        baseNow: now,
        dayOfWeek: dayOfWeek,
        hour: s.hour,
        minute: s.minute,
      );
      try {
        await _plugin.zonedSchedule(
          notifId,
          s.title,
          body,
          firstFire,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // Haftalık tekrar — sadece bu gün + saat eşleşince tetiklenir.
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: s.categoryId,
        );
        debugPrint('[Pusula][Sched] $notifId (${_dayName(dayOfWeek)}) '
            '→ ${firstFire.toIso8601String()}');
      } catch (e) {
        debugPrint('[Pusula][Sched] zonedSchedule hata (id $notifId): $e');
      }
    }
  }

  /// `dayOfWeek` (1=Pzt..7=Paz) için, verilen saat-dakikadaki bir
  /// sonraki occurrence'ı döner. Bugün o günse ve saat geçmediyse bugün,
  /// aksi halde gelecek hafta aynı gün.
  static tz.TZDateTime _nextOccurrenceOfDay({
    required tz.TZDateTime baseNow,
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) {
    var candidate = tz.TZDateTime(
      tz.local,
      baseNow.year,
      baseNow.month,
      baseNow.day,
      hour,
      minute,
    );
    // baseNow.weekday: 1..7 (DateTime convention). dayOfWeek aynı şema.
    final daysAhead = (dayOfWeek - baseNow.weekday) % 7;
    candidate = candidate.add(Duration(days: daysAhead));
    if (!candidate.isAfter(baseNow)) {
      // Bugün ama saat geçmiş → 1 hafta sonraya at.
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  static String _dayName(int d) {
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    if (d < 1 || d > 7) return 'gün$d';
    return names[d - 1];
  }
}
