# 🔥 Firebase Setup — Pusula

Push bildirimleri (son dakika, kategori ve keyword bazlı uyarılar) için
Firebase Cloud Messaging (FCM) kullanıyoruz.

> **Önemli:** Firebase config dosyaları (`google-services.json` ve
> `GoogleService-Info.plist`) repo'da **yok** — onları sen kendi Firebase
> projenden indireceksin. Bu bir kez yapılır, sonra `flutter run` push
> çalışır hâlde olur.

---

## 📋 İçindekiler

1. [Firebase projesi oluştur](#1-firebase-projesi-oluştur-5-dk)
2. [flutterfire CLI ile configure](#2-flutterfire-cli-ile-configure-10-dk)
3. [Android entegrasyon](#3-android-entegrasyon)
4. [iOS entegrasyon](#4-ios-entegrasyon)
5. [Test mesajı gönder](#5-test-mesajı-gönder-2-dk)
6. [Topic stratejisi](#6-topic-stratejisi)
7. [Sorun giderme](#7-sorun-giderme)

---

## 1. Firebase projesi oluştur (5 dk)

1. https://console.firebase.google.com/ adresine git.
2. **Add project** veya **Proje ekle** butonuna bas.
3. Proje adı: `Pusula News` (veya istediğin).
4. Google Analytics: **Disable** (push için gerek yok; isteğe bağlı).
5. **Create project** → bekle → **Continue**.

Bu kadar. Henüz hiçbir platform eklemeyeceksin — bir sonraki adımdaki
CLI bunu otomatik yapacak.

---

## 2. flutterfire CLI ile configure (10 dk)

Tek komut ile Android + iOS Firebase config dosyalarını üretir,
`pubspec.yaml`'a gerekli plugin'leri kontrol eder.

### 2.1 — flutterfire CLI yükle (bir kez)

```powershell
dart pub global activate flutterfire_cli
```

PATH'e ekleme uyarısı görürsen:
```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```
(veya kalıcı için Sistem ortam değişkenlerinden ekle).

### 2.2 — Repo kök dizininde configure et

```powershell
cd D:\Github\mobil_haber
flutterfire configure
```

Komut adımları:
1. Hangi Firebase projesine bağlanacağını sorar — listeden seç.
2. Hangi platformları destekleyeceksin → `android` ve `ios` seç (web/macOS/windows opsiyonel).
3. Otomatik üretir:
   - `android/app/google-services.json` ✅
   - `ios/Runner/GoogleService-Info.plist` ✅
   - `lib/firebase_options.dart` ✅ (DefaultFirebaseOptions)

### 2.3 — `firebase_options.dart` kullan

`lib/main.dart` Firebase init'i `Firebase.initializeApp()` ile çağırır.
flutterfire configure tamamlandıktan sonra otomatik DefaultFirebaseOptions
kullanılır:

```dart
import 'firebase_options.dart';
// ...
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

> Mevcut [push_notification_service.dart](../lib/core/notifications/push_notification_service.dart)
> bu çağrıyı try/catch sarmalı yapıyor — `firebase_options.dart` yokken
> hata fırlatmaz, sessizce skip eder.

---

## 3. Android entegrasyon

`flutterfire configure` çoğunu otomatik yapar. Manuel kontrol için:

### 3.1 — `android/settings.gradle.kts`

```kotlin
plugins {
    // ... mevcut
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

### 3.2 — `android/app/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ← bunu ekle
}
```

### 3.3 — minSdk kontrolü

Pusula `minSdk = 24` kullanır (zaten ayarlı). Daha düşük olursa Firebase
plugin'leri bağırır.

---

## 4. iOS entegrasyon

Xcode ile aç:
```powershell
open ios/Runner.xcworkspace
```

(Windows kullanıyorsan iOS build'i sadece macOS'ta yapılabilir; bu adımları
Mac'inde yap.)

### 4.1 — Push Notifications capability

1. Runner target seç → **Signing & Capabilities** sekmesine git.
2. **+ Capability** → **Push Notifications** ekle.
3. **+ Capability** → **Background Modes** → `Remote notifications`'ı işaretle.
   (`Audio` zaten Pusula tarafından eklenmiş.)

### 4.2 — APN sertifikası

1. https://developer.apple.com/account/resources/authkeys/list adresinden
   yeni APNs Authentication Key oluştur (`Key ID` ve `.p8` dosyası).
2. Firebase Console → Project Settings → Cloud Messaging sekmesi →
   **APNs Authentication Key** bölümüne `.p8`'i yükle.

---

## 5. Test mesajı gönder (2 dk)

### 5.1 — Console'dan

Firebase Console → **Cloud Messaging** → **Send your first message**:

| Alan | Değer |
|---|---|
| Notification title | `Test bildirimi` |
| Notification text | `Pusula push çalışıyor 🎉` |
| Send → **Topic** | `breaking-news` |

Pusula varsayılan olarak `breaking-news` topic'ine abonedir.

### 5.2 — Token ile direkt

Eğer topic değil de spesifik cihazına test edeceksin:

1. Pusula'yı `flutter run` ile başlat.
2. Konsol log'unda şunu ara:
   ```
   [Pusula][FCM] token: <ilk 16 karakter>…
   ```
3. Token'ın tamamı için `getToken()` çağrısının çıktısını al
   (debug build'de tam token log'lanır).
4. Console'da **Send test message** → **Add an FCM registration token**
   → token'ı yapıştır → Test.

---

## 6. Topic stratejisi

Pusula push hiyerarşisi:

| Topic | Ne zaman | Default |
|---|---|---|
| `breaking-news` | Tüm kullanıcılar — son dakika haberleri | ✅ Açık |
| `category-{id}` | Belirli kategori (`category-spor`, `category-ekonomi`) | Manuel |
| `kw-{slug}` | Anahtar kelime match (`kw-galatasaray`, `kw-bitcoin`) | Manuel |

> Slug: lowercase + Türkçe karakter normalize (ı→i, ş→s, ç→c, ö→o, ü→u, ğ→g).

### Backend tarafında

Yeni bir RSS makalesi geldiğinde:

```php
// Pseudocode
foreach ($newArticles as $article) {
  // 1. Tüm kullanıcılara ulaştır (son dakika)
  if ($article->isBreaking) {
    fcm_send(topic: 'breaking-news', title: $article->title, ...);
  }
  // 2. Kategori takipçilerine
  fcm_send(topic: "category-{$article->categoryId}", ...);
  // 3. Keyword match
  foreach ($keywords as $kw) {
    if (matches($article, $kw)) {
      fcm_send(topic: "kw-" . slugify($kw), ...);
    }
  }
}
```

Server-side topic gönderimi için Firebase Cloud Functions, kendi PHP/Node
sunucun veya Cloud Tasks kullanabilirsin. Server key Firebase Console
> Project Settings > Service accounts'tan alınır — **asla client'a gömme**.

---

## 7. Sorun giderme

### "Default FirebaseApp is not initialized"
- `flutterfire configure` çalıştırılmamış.
- `lib/main.dart` içinde `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` mı çağrılıyor?

### Android: "google-services.json missing"
- `android/app/google-services.json` var mı?
- `flutterfire configure` çalıştırdıktan sonra `flutter clean && flutter run`.

### iOS: "Missing GoogleService-Info.plist"
- `ios/Runner/GoogleService-Info.plist` var mı?
- Xcode'da **Runner** target'a eklendi mi (drag-drop edip target'ı işaretle)?

### Push gelmiyor (Android)
1. `[Pusula][FCM] token: …` log'u görüyor musun? Hayırsa init başarısız.
2. Cihaz battery optimization → uygulama whitelist'e eklenmiş mi?
3. Topic doğru mu? `breaking-news` (lower-case, hyphen).
4. Console'dan test mesajı gönderdin mi?

### Push gelmiyor (iOS)
1. Real device kullanıyor musun? Simulator'da push çalışmaz.
2. Push Notifications capability açık mı?
3. APNs key Firebase'e yüklendi mi?
4. Cihazda bildirim izni verildi mi (Settings > Pusula > Notifications)?

### Free tier limitleri
- FCM **tamamen ücretsiz**, kullanıcı sayısı sınırsız.
- Payload max **4 KB** (Pusula tipik 200B kullanır).
- Aynı topic'e saniyede 240 mesaj limiti var.

---

## Production notları

- **Server key güvenliği**: Firebase Console → Project Settings → Service
  accounts → "Generate new private key". Bu JSON server'da, `.env`'de
  veya secrets manager'da saklanır.
- **Test environment**: Firebase'de production projesi yanına `pusula-staging`
  diye ayrı bir proje oluştur, debug build için onu kullan.
- **Crashlytics**: Bu repo şu an sadece FCM kullanıyor; crash report
  istersen `firebase_crashlytics` paketini ekle ve `flutterfire configure`
  tekrar çalıştır.
