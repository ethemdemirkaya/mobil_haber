import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'briefing_audio_cache.dart';
import 'briefing_player.dart';

/// Cihazın yerleşik TTS'i (flutter_tts).
///
/// Cümle bitişi platform olaylarıyla bildirilir; kesilen cümlenin geç
/// gelen iptal olayı [UtteranceSequencer] ile süzülür.
class SystemTtsEngine extends UtteranceEngine {
  SystemTtsEngine(this._tts) {
    _tts.setStartHandler(_sequencer.onStart);
    _tts.setCompletionHandler(() => _sequencer.onTerminal(finished: true));
    _tts.setCancelHandler(() => _sequencer.onTerminal(finished: false));
    _tts.setErrorHandler(
        (msg) => _sequencer.onError(Exception('Sistem TTS hatası: $msg')));
  }

  final FlutterTts _tts;
  final UtteranceSequencer _sequencer = UtteranceSequencer();
  double? _appliedSpeed;

  @override
  bool get supportsPitch => true;

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  @override
  Future<bool> speak(String text, {required double speed}) async {
    if (_appliedSpeed != speed) {
      // flutter_tts: 0.5 = normal hız (Android/iOS).
      await _tts.setSpeechRate(speed * 0.5);
      _appliedSpeed = speed;
    }
    final done = _sequencer.begin();
    final result = await _tts.speak(text);
    if (result != 1) {
      _sequencer.cancelCurrent();
      throw Exception('Sistem TTS cümleyi okuyamadı (speak=$result).');
    }
    // Başlangıç olayı gelmeyen motorlar için güvenlik: kısa süre sonra
    // terminal olayları kabul etmeye başla.
    unawaited(Future<void>.delayed(const Duration(seconds: 2))
        .then((_) => _sequencer.assumeStarted()));
    return done.timeout(
      _maxDuration(text, speed),
      onTimeout: () {
        debugPrint('[Pusula][SystemTTS] cümle süresi aşıldı, geçiliyor');
        _sequencer.cancelCurrent();
        return true;
      },
    );
  }

  /// Takılma emniyeti: Türkçe ~14 karakter/sn varsayımının üç katı.
  static Duration _maxDuration(String text, double speed) => Duration(
        milliseconds: (text.length / (14 * speed) * 3000).round() + 8000,
      );

  @override
  Future<void> interrupt() async {
    final wasWaiting = _sequencer.isWaiting;
    _sequencer.cancelCurrent();
    if (wasWaiting) await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}

/// MP3 üreten motorlar (Edge, OpenAI, ElevenLabs) için ortak oynatıcı.
///
/// - Ses her zaman 1.0 hızında üretilir ve önbelleklenir; hız oynatıcının
///   `playbackRate`'i ile **anında** değişir — eskiden her hız
///   değişikliğinde cümle o hızda yeniden üretiliyor ve baştan başlıyordu.
/// - Bir sonraki cümle çalan cümle sürerken hazırlanır ([prefetch]);
///   cümle aralarındaki 1-2 sn'lik boşluklar kalkar.
/// - Duraklatma cümle ortasında kalır, devam oradan sürer.
class AudioFileEngine extends UtteranceEngine {
  AudioFileEngine({
    required AudioPlayer player,
    required this.cacheVoice,
    required this.cacheModel,
    required this.synthesize,
  }) : _player = player;

  final AudioPlayer _player;

  /// Disk önbelleği anahtarının parçaları (ses + model).
  final String cacheVoice;
  final String cacheModel;

  /// Metni 1.0 hızında MP3'e çevirir.
  final Future<Uint8List> Function(String text) synthesize;

  final Map<String, Future<Source>> _prepared = <String, Future<Source>>{};
  Completer<bool>? _current;
  StreamSubscription<void>? _completeSub;
  double _rate = 1.0;
  bool _pauseRequested = false;

  @override
  bool get canChangeSpeedLive => true;

  @override
  bool get canPauseInPlace => true;

  @override
  void prefetch(String text) {
    // Hata çalma sırasında yeniden denenir; burada sessizce yut.
    unawaited(_prepare(text).then((_) {}, onError: (_) {}));
  }

  Future<Source> _prepare(String text) {
    return _prepared.putIfAbsent(text, () async {
      final cached = await BriefingAudioCache.find(
        text: text,
        voice: cacheVoice,
        model: cacheModel,
        speed: 1.0,
      );
      if (cached != null) return DeviceFileSource(cached.path);
      final bytes = await synthesize(text);
      unawaited(BriefingAudioCache.store(
        text: text,
        voice: cacheVoice,
        model: cacheModel,
        speed: 1.0,
        bytes: bytes,
      ));
      return BytesSource(bytes);
    }).catchError((Object e) {
      _prepared.remove(text); // başarısız hazırlık önbellekte kalmasın
      throw e;
    });
  }

  @override
  Future<bool> speak(String text, {required double speed}) async {
    final source = await _prepare(text);
    _prepared.remove(text);
    final done = Completer<bool>();
    _current = done;
    await _completeSub?.cancel();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (identical(_current, done) && !done.isCompleted) {
        _current = null;
        done.complete(true);
      }
    });
    _rate = speed;
    await _player.stop();
    if (!identical(_current, done)) return false; // bu arada kesildi
    await _player.play(source);
    // Bazı platformlar hızı kaynak yüklenince sıfırlar; play'den sonra uygula.
    await _player.setPlaybackRate(_rate);
    // Ses hazırlanırken duraklatıldıysa hemen duraklat.
    if (_pauseRequested) await _player.pause();
    return done.future;
  }

  @override
  Future<void> interrupt() async {
    _pauseRequested = false;
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete(false);
    await _completeSub?.cancel();
    _completeSub = null;
    await _player.stop();
  }

  @override
  Future<void> setLiveSpeed(double speed) async {
    _rate = speed;
    if (_current != null) await _player.setPlaybackRate(speed);
  }

  @override
  Future<void> pauseInPlace() async {
    _pauseRequested = true;
    await _player.pause();
  }

  @override
  Future<void> resumeInPlace() async {
    _pauseRequested = false;
    await _player.resume();
    await _player.setPlaybackRate(_rate);
  }

  @override
  Future<void> dispose() async {
    await _completeSub?.cancel();
    _prepared.clear();
  }
}
