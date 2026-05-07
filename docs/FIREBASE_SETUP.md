# Firebase Setup — Pusula

Push bildirimleri (Son dakika, kategori ve keyword bazlı uyarılar) için
Firebase Cloud Messaging (FCM) kullanıyoruz.

Bu adımları **bir kez** yapman yeterli — sonra `flutter run` /
`./run.ps1` push çalışır hâlde olur.

---

## 1. Firebase projesi oluştur (5 dk)

1. https://console.firebase.google.com/ → **Add project**.
2. Proje adı: `Pusula News` (veya istediğin).
3. Google Analytics: **Disable** (push için gerek yok; isteğe bağlı).
4. Create project → Continue.

## 2. flutterfire CLI ile platform configure (10 dk)

Tek komut ile Android + iOS Firebase config dosyalarını üretir.

```powershell
# Bir kez yüklemek yeterli
dart pub global activate flutterfire_cli

# Repo kök dizininde
flutterfire configure --project=<firebase-project-id>
```

Komut neler yapar:
- Android: `android/app/google-services.json` indirir.
- iOS: `ios/Runner/GoogleService-Info.plist` indirir.
- Dart: `lib/firebase_options.dart` generate eder (her platformun
  `FirebaseOptions`'ını içerir).
- `pubspec.yaml`'a gerekli plugin'leri ekler (zaten ekli).

Bu üç dosya **gitignore'a alınmıyor** — repo public ise sızdırma riski
yok (sadece public client config'i içerir, server key yok).

## 3. Android'e bağla

`android/build.gradle` ya da `android/settings.gradle.kts` (Gradle 8+):

```kotlin
plugins {
    // ... mevcut Flutter plugin'i
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

`android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ← yeni
}
```

`flutterfire configure` zaten bunu otomatik yapar; manuel kontrol için.

## 4. iOS'a bağla

Xcode'da:
1. Runner target → **Signing & Capabilities** → `+` → **Push Notifications**.
2. Background modes → `Remote notifications` ve `Audio` aktif.
3. APN sertifikası: Apple Developer Portal'dan sertifika indir →
   Firebase console > Project Settings > Cloud Messaging > APNs
   Authentication Key bölümüne yükle.

## 5. main.dart entegrasyonu

Zaten ekli. `lib/main.dart` içinde:

```dart
await PushNotificationService.init(localNotifs: ...);
```

flutterfire configure tamamlandıktan sonra Firebase.initializeApp()
otomatik çalışır.

## 6. Test mesajı gönder

Firebase console > Cloud Messaging > **Send your first message**:
- Title: "Test bildirimi"
- Body: "Pusula push çalışıyor 🎉"
- Target: **Topic** → `breaking-news`

App'in `breaking-news` topic'ine abonedir (varsayılan).

## 7. Topic stratejisi

Pusula push hiyerarşisi:
- `breaking-news` — herkes (varsayılan).
- `category-spor`, `category-ekonomi` — kullanıcının takip ettiği
  kategoriler için (ileride otomatik subscription).
- `kw-galatasaray`, `kw-bitcoin` — keyword filter eklenince
  otomatik abone (slug normalize: lowercase, ı→i, ş→s, vb.).

Backend tarafında: yeni RSS makalesi geldiğinde, başlık ve özetinde
keyword match varsa o keyword'ün topic'ine FCM mesajı yolla.

---

## Production notları

- **Free tier**: FCM tamamen ücretsiz, kullanıcı sayısı sınırsız.
- **Veri kullanımı**: Push payload max 4KB; bizim use case'imizde 200B
  yeterli (title + body + categoryId).
- **Backend**: Firebase Cloud Functions veya kendi Node/PHP sunucun ile
  topic'lere mesaj gönder. Server key Firebase console'dan alınır,
  asla client'a gömme.
- **Test**: APK debug build'de `Firebase.initializeApp()` patlarsa
  app yine açılır (try/catch sarmalı); release'de eksik dosya = derleme
  hatası verir.
