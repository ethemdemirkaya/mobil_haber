# ┌──────────────────────────────────────────────────────────────────────┐
# │ Pusula — Firebase tek-komut setup                                    │
# │                                                                      │
# │ Ne yapar:                                                            │
# │   1. flutterfire CLI yüklü değilse yükler.                          │
# │   2. PATH'e ekler (geçici olarak; oturum süresince).                │
# │   3. flutterfire configure'ı pusula-news projesine bağlanacak       │
# │      şekilde çalıştırır → google-services.json + GoogleService-     │
# │      Info.plist + lib/firebase_options.dart üretilir.               │
# │   4. main.dart Firebase.initializeApp çağrısını otomatik             │
# │      DefaultFirebaseOptions ile çalışacak şekilde günceller.        │
# │   5. flutter clean + pub get yapar, build hazır olur.               │
# │                                                                      │
# │ Kullanım:                                                            │
# │   .\setup-firebase.ps1                                              │
# │                                                                      │
# │ Not: Komut bir kez çalışır; bittikten sonra `flutter run` push     │
# │ destekli halde başlar.                                              │
# └──────────────────────────────────────────────────────────────────────┘

$ErrorActionPreference = "Stop"

$projectId = "pusula-news"

Write-Host ""
Write-Host "┌─ Pusula Firebase setup ─────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│ Proje:       $projectId" -ForegroundColor Cyan
Write-Host "│ Hedef:       Android + iOS                                       │" -ForegroundColor Cyan
Write-Host "└─────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# 1. flutterfire CLI yüklü mü?
$pubBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
if (-not ($env:Path -like "*$pubBin*")) {
    $env:Path = "$env:Path;$pubBin"
}

$cliFound = Get-Command flutterfire -ErrorAction SilentlyContinue
if (-not $cliFound) {
    Write-Host "→ flutterfire CLI yüklü değil; yükleniyor..." -ForegroundColor Yellow
    dart pub global activate flutterfire_cli
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ flutterfire CLI yüklemesi başarısız." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ flutterfire CLI bulundu: $($cliFound.Source)" -ForegroundColor Green
}

# 2. Firebase login kontrolü (firebase tools yerine flutterfire'ın
#    kendi auth flow'una güveniyoruz — gerekirse browser açar).

# 3. flutterfire configure
Write-Host ""
Write-Host "→ flutterfire configure başlatılıyor..." -ForegroundColor Yellow
Write-Host "   Browser açılırsa Google hesabınla Firebase'e giriş yap." -ForegroundColor DarkGray
Write-Host ""

flutterfire configure `
    --project=$projectId `
    --platforms=android,ios `
    --android-package-name=com.ethemdemirkaya.pusula `
    --ios-bundle-id=com.ethemdemirkaya.pusula `
    --yes

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ flutterfire configure başarısız oldu." -ForegroundColor Red
    Write-Host "  Browser ile giriş yaptın mı? Proje ID doğru mu? ($projectId)" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✓ Firebase configure tamamlandı." -ForegroundColor Green

# 4. main.dart'ta Firebase.initializeApp(options: DefaultFirebaseOptions...) varsa skip;
#    yoksa otomatik update.
$mainPath = "lib\main.dart"
$mainText = Get-Content $mainPath -Raw
if ($mainText -notmatch "DefaultFirebaseOptions") {
    Write-Host "→ main.dart Firebase.initializeApp çağrısı güncelleniyor..." -ForegroundColor Yellow
    # Bu safhada push_notification_service tarafı zaten Firebase.initializeApp()
    # çağırıyor; firebase_options'ın tek satırlık değişiklikle aktif edilmesi
    # için onu güncelle.
    $svcPath = "lib\core\notifications\push_notification_service.dart"
    $svcText = Get-Content $svcPath -Raw
    if ($svcText -notmatch "firebase_options.dart") {
        $svcText = $svcText -replace "import 'package:firebase_core/firebase_core.dart';", `
            "import 'package:firebase_core/firebase_core.dart';`r`nimport '../../firebase_options.dart';"
        $svcText = $svcText -replace "await Firebase\.initializeApp\(\);", `
            "await Firebase.initializeApp(`r`n        options: DefaultFirebaseOptions.currentPlatform,`r`n      );"
        Set-Content $svcPath $svcText -Encoding utf8
        Write-Host "✓ push_notification_service.dart DefaultFirebaseOptions kullanıyor." -ForegroundColor Green
    }
}

# 5. flutter clean + pub get
Write-Host ""
Write-Host "→ flutter clean + pub get..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host ""
Write-Host "┌─ Setup tamamlandı! ──────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "│                                                                  │" -ForegroundColor Green
Write-Host "│  Sıra:                                                           │" -ForegroundColor Green
Write-Host "│  1. .\run.ps1  (veya VSCode'da F5)                              │" -ForegroundColor Green
Write-Host "│  2. Firebase Console > Cloud Messaging > Send first message     │" -ForegroundColor Green
Write-Host "│     Topic: breaking-news                                        │" -ForegroundColor Green
Write-Host "│                                                                  │" -ForegroundColor Green
Write-Host "│  iOS için ek: Xcode'da Push Notifications + Background Modes    │" -ForegroundColor Green
Write-Host "│  capability ekle. APN sertifikası Firebase'e yükle.            │" -ForegroundColor Green
Write-Host "│                                                                  │" -ForegroundColor Green
Write-Host "│  Detay: docs\FIREBASE_SETUP.md                                  │" -ForegroundColor Green
Write-Host "└─────────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""
