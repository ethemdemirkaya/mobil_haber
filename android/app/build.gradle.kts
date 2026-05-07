plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase google-services.json'ı build'a inject eder.
    // flutterfire configure çalıştırıldıktan sonra google-services.json
    // bu klasöre düşer ve plugin onu kullanır.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ethemdemirkaya.pusula"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications Java 8 API'leri (java.time vs)
        // kullandığı için core library desugaring şart. Bu olmadan
        // "Dependency requires core library desugaring" hatası verir.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ethemdemirkaya.pusula"
        // flutter_local_notifications + firebase_messaging + audio_session
        // Android API 24+ destekliyor. Flutter default minSdk (21) bazı
        // plugin'lerin requirement'larıyla çakışıyor.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Java 8+ API'lerinin (java.time, java.util.stream vb.) eski Android
    // API seviyelerine derlenmesi için. flutter_local_notifications zorunlu.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
