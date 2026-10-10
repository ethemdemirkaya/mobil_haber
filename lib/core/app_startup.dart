import 'package:flutter/foundation.dart';
import 'tts/audio_session_setup.dart';
import 'tts/briefing_audio_handler.dart';

/// Media preparation is shared by startup and briefing, never blocking a frame.
abstract final class AppStartup {
  static Future<void>? _audio;
  static Future<void> prepareAudio() => _audio ??= _prepareAudio();
  static Future<void> _prepareAudio() async {
    for (final step in <Future<void> Function()>[
      AudioSessionSetup.configure,
      BriefingAudioHandler.bootstrap,
    ]) {
      try {
        await step().timeout(const Duration(seconds: 6));
      } catch (error) {
        debugPrint('[Pusula][media init] $error');
      }
    }
  }
}
