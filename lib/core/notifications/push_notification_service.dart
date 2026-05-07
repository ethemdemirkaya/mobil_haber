import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pusula push bildirim katmanı (Firebase Cloud Messaging).
///
/// **Çalışma kapsamı:**
/// 1. Firebase init (DefaultFirebaseOptions otomatik configure'dan
///    okunur — flutterfire_cli ile generate edilir).
/// 2. Bildirim izni iste (iOS/Android 13+).
/// 3. FCM token al (debug log; production'da backend'e gönderilir).
/// 4. Topic subscription: `breaking-news`, `category-{id}`, ve kullanıcının
///    eklediği keyword'ler için `kw-{slug}` topic'leri.
/// 5. Ön planda gelen mesajları flutter_local_notifications ile sistem
///    notif olarak göster (FCM ön planda otomatik göstermez).
///
/// **Kurulum gerekliliği:** docs/FIREBASE_SETUP.md adımlarını izle:
///   - Firebase console'da proje oluştur.
///   - flutterfire configure ile platform dosyalarını üret.
///   - Android: google-services.json → android/app/.
///   - iOS: GoogleService-Info.plist → ios/Runner/.
///   - APN sertifikası (iOS) veya FCM sender ID (Android) ayarla.
///
/// Bu sınıf Firebase config dosyaları yokken `init()` sessizce başarısız
/// olur — uygulama yine açılır, sadece push çalışmaz.
class PushNotificationService {
  PushNotificationService._();

  static const String _prefsTopicPrefix = 'pref_fcm_topic_';
  static bool _initialized = false;
  static String? _token;

  static String? get fcmToken => _token;
  static bool get isInitialized => _initialized;

  /// Uygulama açıldığında main()'dan çağrılır. Hata olursa logla, devam et.
  static Future<void> init({
    required FlutterLocalNotificationsPlugin localNotifs,
  }) async {
    if (_initialized) return;
    try {
      // flutterfire configure çalışmışsa lib/firebase_options.dart üretilir
      // ve aşağıdaki dynamic import yerine doğrudan kullanılır. Bu
      // koşullu yaklaşım, dosya yokken bile derlemenin kırılmamasını sağlar.
      // Kurulum tamamlandıktan sonra istersen bu satırı:
      //   await Firebase.initializeApp(
      //     options: DefaultFirebaseOptions.currentPlatform,
      //   );
      // ile değiştirebilirsin (firebase_options.dart import et).
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Pusula][FCM] Firebase init başarısız: $e\n'
          '→ Setup için: ./setup-firebase.ps1 (veya docs/FIREBASE_SETUP.md)');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // İzin (iOS + Android 13+)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Pusula][FCM] kullanıcı bildirim iznini reddetti.');
      }

      // Token (debug)
      _token = await messaging.getToken();
      if (_token != null) {
        debugPrint('[Pusula][FCM] token: ${_token!.substring(0, 16)}…');
      }

      // Token rotasyon — production'da backend'e POST.
      messaging.onTokenRefresh.listen((t) {
        _token = t;
        debugPrint('[Pusula][FCM] token yenilendi.');
      });

      // Default topic: tüm kullanıcılar son dakika'ya abone (toggle ile
      // kapatılabilir).
      await ensureTopic('breaking-news', enabled: true);

      // Ön planda gelen mesajları lokal notif olarak göster.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final notif = message.notification;
        if (notif == null) return;
        await localNotifs.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          notif.title ?? 'Pusula',
          notif.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'pusula_push_channel',
              'Pusula Push Bildirimleri',
              channelDescription: 'Son dakika ve önemli haberler.',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: message.data['payload']?.toString(),
        );
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[Pusula][FCM] messaging init hata: $e');
    }
  }

  /// Bir topic'e abone ol/abonelikten çık ve tercihi shared_prefs'e yaz.
  /// Kullanıcı toggle'larında çağrılır.
  static Future<void> ensureTopic(String topic, {required bool enabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messaging = FirebaseMessaging.instance;
      if (enabled) {
        await messaging.subscribeToTopic(topic);
        await prefs.setBool('$_prefsTopicPrefix$topic', true);
      } else {
        await messaging.unsubscribeFromTopic(topic);
        await prefs.setBool('$_prefsTopicPrefix$topic', false);
      }
    } catch (e) {
      debugPrint('[Pusula][FCM] topic $topic hata: $e');
    }
  }

  /// Bir topic'e abone miyiz (lokal cache; gerçek durumu sorgulayan API
  /// FCM tarafından sağlanmıyor).
  static Future<bool> isSubscribedTo(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefsTopicPrefix$topic') ?? false;
  }
}
