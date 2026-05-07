import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// İşletim sistemi seviyesinde "ben şu an konuşma sesi çalıyorum"
/// configuration'u. Buna olmadan:
///   - iOS: app arkaplana atılınca ses durur, sessize alınınca da
///     çalmaz, başka bir uygulama ses çalmaya başlayınca kesilmez.
///   - Android: müzik çalan uygulamayla AudioFocus çakışması.
///
/// `AudioSession.configure(speech)` preset'i:
///   - iOS: AVAudioSession.Category.playback + spokenAudio mode +
///     duckOthers (başka bir uygulama ses çalarsa diğerini düşür).
///   - Android: stream USAGE_ASSISTANCE_NAVIGATION_GUIDANCE +
///     CONTENT_TYPE_SPEECH + AudioFocus gainTransientMayDuck.
///
/// Bu sınıf tek seferlik global config; main()'dan çağrılır.
class AudioSessionSetup {
  AudioSessionSetup._();

  static bool _configured = false;

  /// Tek seferlik configure. Hata olursa sessizce log'a düşer; ses
  /// yine çalar (sadece arka plan davranışı suboptimal).
  static Future<void> configure() async {
    if (_configured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
      _configured = true;
    } catch (e) {
      debugPrint('[Pusula][AudioSession] configure başarısız: $e');
    }
  }
}
