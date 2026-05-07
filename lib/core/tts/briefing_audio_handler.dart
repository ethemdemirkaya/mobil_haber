import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';

/// `audio_service` paketi ile lock screen + bildirim panel medya kontrolü.
///
/// Bu handler `audioplayers` üzerinden çalan MP3 (OpenAI TTS sonucu)
/// için lock screen'de play/pause/stop/skip butonlarını ve "now playing"
/// metadata'sını sağlar. Sistem TTS (flutter_tts) için medya kontrolü
/// platform desteği sınırlı — flutter_tts tarafı `mediaItem` günceller
/// ama gerçek control native handler'a düşer.
///
/// Akış:
///   1. main.dart `AudioService.init` ile bu handler'ı kaydeder.
///   2. DailyBriefingScreen başlarken `setMediaItem()` ile başlık/sanatçı
///      set eder.
///   3. OpenAI TTS bytes/file çalmaya başlamadan önce `setPlaybackState`
///      ile playing=true yayar.
///   4. Lock screen'den kullanıcı play/pause yapınca buradaki callback'ler
///      ekrandaki state'i tetikler (callback'ler `tappedAction` üzerinden
///      UI'a yansır).
class BriefingAudioHandler extends BaseAudioHandler {
  BriefingAudioHandler() {
    // Sürekli audioplayer state'ini izleyip kendi state'imize yansıt.
    _player.onPlayerStateChanged.listen((state) {
      _publishState(state);
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      _publishState(_player.state);
    });
    _player.onPositionChanged.listen((p) {
      _publishState(_player.state, position: p);
    });
  }

  /// İçeride yönetilen tek audio player. DailyBriefingScreen
  /// tarafındaki `_audioPlayer` yerine BU kullanılır — yoksa lock screen
  /// state'i sync olmaz.
  final ap.AudioPlayer _player = ap.AudioPlayer();
  ap.AudioPlayer get player => _player;

  Duration _duration = Duration.zero;

  /// UI tarafının lock-screen butonuna basıldığını öğrenmesi için stream.
  final StreamController<BriefingLockAction> _actionCtrl =
      StreamController<BriefingLockAction>.broadcast();
  Stream<BriefingLockAction> get actions => _actionCtrl.stream;

  /// Üst widget brifing başlattığında çağırır → notification panelinde
  /// "Şu an çalıyor" bilgisi.
  Future<void> setBriefingItem({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: 'Pusula',
      duration: duration,
    ));
  }

  void _publishState(ap.PlayerState state, {Duration? position}) {
    final playing = state == ap.PlayerState.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: switch (state) {
        ap.PlayerState.stopped => AudioProcessingState.idle,
        ap.PlayerState.completed => AudioProcessingState.completed,
        ap.PlayerState.paused => AudioProcessingState.ready,
        ap.PlayerState.playing => AudioProcessingState.ready,
        ap.PlayerState.disposed => AudioProcessingState.idle,
      },
      playing: playing,
      updatePosition: position ?? Duration.zero,
      bufferedPosition: _duration,
      speed: 1.0,
    ));
  }

  // ─── BaseAudioHandler override'ları ───
  // Bu callback'ler lock screen butonlarından gelir, bizim UI'a sinyal
  // veriyoruz; UI gerçek aksiyonu (play_from_index vb.) gerçekleştirir.
  @override
  Future<void> play() async {
    debugPrint('[Pusula][AudioHandler] play() lock-screen');
    _actionCtrl.add(BriefingLockAction.play);
  }

  @override
  Future<void> pause() async {
    debugPrint('[Pusula][AudioHandler] pause() lock-screen');
    _actionCtrl.add(BriefingLockAction.pause);
  }

  @override
  Future<void> stop() async {
    debugPrint('[Pusula][AudioHandler] stop() lock-screen');
    _actionCtrl.add(BriefingLockAction.stop);
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('[Pusula][AudioHandler] skipToNext()');
    _actionCtrl.add(BriefingLockAction.skipNext);
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('[Pusula][AudioHandler] skipToPrevious()');
    _actionCtrl.add(BriefingLockAction.skipPrev);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    super.onTaskRemoved();
  }

  /// Singleton — main.dart içinde init edilir, UI başka yerden okur.
  static BriefingAudioHandler? _instance;
  static BriefingAudioHandler get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'BriefingAudioHandler init edilmedi. main()\'da '
        'BriefingAudioHandler.bootstrap() çağırılmalı.',
      );
    }
    return i;
  }

  static bool _booted = false;
  static bool get isBooted => _booted;

  /// Uygulama başlarken bir kez çağırılır. AudioService.init başarısız
  /// olursa (ör. desktop platformlar) sessizce skip — lock-screen kontrolü
  /// olmaz, app yine çalışır.
  static Future<void> bootstrap() async {
    if (_booted) return;
    try {
      _instance = await AudioService.init(
        builder: BriefingAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.ethemdemirkaya.pusula.audio',
          androidNotificationChannelName: 'Pusula sesli brifing',
          androidNotificationChannelDescription:
              'Sesli brifing oynatma kontrolleri.',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: false,
          androidStopForegroundOnPause: true,
          // notification iconu: Android default ic_launcher fallback'i
          // çalışacak; özel beyaz mono icon kullanmak istenirse
          // android/app/src/main/res/drawable/ic_stat_pusula.png eklenir.
        ),
      );
      _booted = true;
    } catch (e) {
      debugPrint('[Pusula][AudioHandler] bootstrap başarısız: $e');
    }
  }
}

/// Lock screen butonundan gelen aksiyon türleri — UI bu enum'la kendi
/// handler'larını çağırır.
enum BriefingLockAction { play, pause, stop, skipNext, skipPrev }
