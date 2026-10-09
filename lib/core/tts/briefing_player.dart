import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tek bir cümleyi seslendiren motor (sistem TTS, Edge, OpenAI, ElevenLabs).
///
/// Sözleşme:
///   - [speak] cümle **doğal olarak bitince** `true`, [interrupt] ile
///     kesilince `false` döner; hata durumunda istisna fırlatır.
///   - [interrupt] çağrıldığında bekleyen [speak] mutlaka tamamlanmalıdır.
abstract class UtteranceEngine {
  Future<bool> speak(String text, {required double speed});

  Future<void> interrupt();

  /// Bir sonraki cümleyi arka planda hazırla (ör. MP3'ü indir); cümleler
  /// arasında bekleme olmasın. Varsayılan: hiçbir şey yapma.
  void prefetch(String text) {}

  /// Hız, çalan cümleyi kesmeden anında değiştirilebiliyor mu?
  /// (MP3 motorlarında oynatma hızı değişir; sistem TTS'te cümle yeniden
  /// başlatılmalıdır.)
  bool get canChangeSpeedLive => false;
  Future<void> setLiveSpeed(double speed) async {}

  /// Duraklatıp kaldığı yerden (cümle ortasından) devam edebiliyor mu?
  bool get canPauseInPlace => false;
  Future<void> pauseInPlace() async {}
  Future<void> resumeInPlace() async {}

  /// Ton ayarı destekleniyor mu? (Yalnızca sistem TTS.)
  bool get supportsPitch => false;
  Future<void> setPitch(double pitch) async {}

  Future<void> dispose() async {}
}

enum BriefingPlaybackStatus { idle, playing, paused }

/// Brifing cümlelerini sırayla çalan, motordan bağımsız oynatıcı.
///
/// Eski ekran içi oynatmada üç hata vardı; bu sınıfın kuralları onları
/// yapısal olarak engeller:
///   - **Hız değişince sona sarma:** durdurulan cümlenin geç gelen
///     "iptal" olayı yeni cümleyi bitmiş sayıyordu. Her oynatma bir
///     [_session] numarası taşır; değişen oturumun sonuçları yok sayılır
///     (motor düzeyindeki koruma için bkz. [UtteranceSequencer]).
///   - **Başa sarma:** "çalıyor" durumu motor olaylarından değil yalnızca
///     bu sınıftan gelir; [play] her zaman [index]'ten devam eder.
///     Baştan başlamak yalnızca [stop] sonrası ya da sona gelindiyse olur.
///   - **Hız/ileri sarma sırasında atlama:** [setSpeed] ve [seek] mevcut
///     cümleyi korur; MP3 motorlarında hız cümle kesilmeden değişir.
class BriefingPlayer extends ChangeNotifier {
  BriefingPlayer({UtteranceEngine? engine}) : _engine = engine;

  UtteranceEngine? _engine;
  List<String> _utterances = const [];
  int _index = 0;
  BriefingPlaybackStatus _status = BriefingPlaybackStatus.idle;
  double _speed = 1.0;
  double _pitch = 1.0;
  Object? _error;
  bool _finished = false;
  bool _disposed = false;

  /// Her yeni oynatma döngüsünde artar; eski döngüler kendini sonlandırır.
  int _session = 0;

  /// Duraklatılmış cümle motor içinde yarıda bekliyor mu (devam
  /// edilebilir) yoksa baştan mı çalınacak?
  bool _pausedInPlace = false;

  List<String> get utterances => _utterances;
  int get index => _index;
  BriefingPlaybackStatus get status => _status;
  bool get isPlaying => _status == BriefingPlaybackStatus.playing;
  bool get isPaused => _status == BriefingPlaybackStatus.paused;
  double get speed => _speed;
  double get pitch => _pitch;
  Object? get error => _error;
  bool get supportsPitch => _engine?.supportsPitch ?? false;
  UtteranceEngine? get engine => _engine;

  /// Motoru değiştirir (ör. ayarlardan Edge → sistem). Çalan cümle
  /// durdurulur, konum korunur.
  Future<void> setEngine(UtteranceEngine engine) async {
    if (identical(engine, _engine)) return;
    final wasPlaying = isPlaying;
    _session++;
    final old = _engine;
    _engine = engine;
    _pausedInPlace = false;
    if (old != null) {
      await old.interrupt();
      await old.dispose();
    }
    if (engine.supportsPitch) await engine.setPitch(_pitch);
    if (wasPlaying) {
      unawaited(_runFrom(_index));
    } else if (isPaused) {
      _notify();
    }
  }

  /// Yeni brifing metnini yükler; çalan varsa durdurur.
  Future<void> load(List<String> utterances) async {
    _session++;
    _pausedInPlace = false;
    await _engine?.interrupt();
    _utterances = List.unmodifiable(utterances);
    _index = 0;
    _finished = false;
    _error = null;
    _status = BriefingPlaybackStatus.idle;
    _notify();
  }

  /// Oynat / devam et. Konum yalnızca [stop] sonrası ya da brifing
  /// sonuna gelindiyse başa döner.
  Future<void> play() async {
    final engine = _engine;
    if (engine == null || _utterances.isEmpty || isPlaying) return;
    _error = null;
    if (isPaused && _pausedInPlace && engine.canPauseInPlace) {
      _pausedInPlace = false;
      _status = BriefingPlaybackStatus.playing;
      _notify();
      await engine.resumeInPlace();
      return;
    }
    if (_finished) {
      _finished = false;
      _index = 0;
    }
    _status = BriefingPlaybackStatus.playing;
    _pausedInPlace = false;
    _notify();
    await _runFrom(_index);
  }

  Future<void> pause() async {
    if (!isPlaying) return;
    final engine = _engine!;
    _status = BriefingPlaybackStatus.paused;
    if (engine.canPauseInPlace) {
      // Döngü bekleyen cümleyle askıda kalır; resumeInPlace onu sürdürür.
      _pausedInPlace = true;
      _notify();
      await engine.pauseInPlace();
    } else {
      _session++;
      _pausedInPlace = false;
      _notify();
      await engine.interrupt();
    }
  }

  Future<void> stop() async {
    _session++;
    _pausedInPlace = false;
    _index = 0;
    _finished = false;
    _status = BriefingPlaybackStatus.idle;
    _notify();
    await _engine?.interrupt();
  }

  /// [target] cümlesine git. Çalıyorsa oradan çalmaya devam eder;
  /// duraklatılmış/durmuşsa konumu ayarlar, [play] oradan başlar.
  Future<void> seek(int target) async {
    if (_utterances.isEmpty) return;
    final idx = target.clamp(0, _utterances.length - 1);
    final wasPlaying = isPlaying;
    _session++;
    _pausedInPlace = false;
    _finished = false;
    _index = idx;
    if (!wasPlaying && _status == BriefingPlaybackStatus.idle && idx > 0) {
      // Durmuşken ileri sarma: "duraklatılmış" konuma geç ki oynat oradan
      // başlasın.
      _status = BriefingPlaybackStatus.paused;
    }
    _notify();
    await _engine?.interrupt();
    if (wasPlaying) unawaited(_runFrom(idx));
  }

  Future<void> skipNext() => seek(_index + 1);
  Future<void> skipPrevious() => seek(_index - 1);

  /// Hızı değiştirir; konum korunur. MP3 motorlarında cümle kesilmez,
  /// sistem TTS'te mevcut cümle yeni hızla baştan okunur.
  Future<void> setSpeed(double speed) async {
    if (speed == _speed) return;
    _speed = speed;
    _notify();
    final engine = _engine;
    if (engine == null) return;
    if (engine.canChangeSpeedLive) {
      await engine.setLiveSpeed(speed);
      return;
    }
    if (isPlaying) {
      _session++;
      await engine.interrupt();
      unawaited(_runFrom(_index));
    } else if (isPaused) {
      // Duraklatılmış cümle yeni hızla baştan okunacak.
      _pausedInPlace = false;
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    _notify();
    final engine = _engine;
    if (engine != null && engine.supportsPitch) await engine.setPitch(pitch);
  }

  Future<void> _runFrom(int start) async {
    final engine = _engine;
    if (engine == null) return;
    final session = ++_session;
    await engine.interrupt();
    if (session != _session) return;
    for (var i = start; i < _utterances.length; i++) {
      if (session != _session) return;
      _index = i;
      if (_status != BriefingPlaybackStatus.playing) {
        // Cümle biterken ya da sıradaki hazırlanırken duraklatıldı:
        // sonraki cümleye geçme, oynat buradan devam etsin.
        _pausedInPlace = false;
        _notify();
        return;
      }
      _notify();
      if (i + 1 < _utterances.length) engine.prefetch(_utterances[i + 1]);
      final bool completed;
      try {
        completed = await engine.speak(_utterances[i], speed: _speed);
      } catch (e) {
        if (session != _session) return;
        debugPrint('[Pusula][Briefing] cümle $i okunamadı: $e');
        _error = e;
        _status = BriefingPlaybackStatus.paused;
        _pausedInPlace = false;
        _notify();
        return;
      }
      if (session != _session) return;
      // Kesildiyse ama oturum değişmediyse (ör. dışarıdan durdurma)
      // ilerleme; durumu duraklatılmışa çek.
      if (!completed) {
        _status = BriefingPlaybackStatus.paused;
        _pausedInPlace = false;
        _notify();
        return;
      }
    }
    if (session != _session) return;
    _finished = true;
    _status = BriefingPlaybackStatus.idle;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      unawaited(engine.interrupt().whenComplete(engine.dispose));
    }
    super.dispose();
  }
}

/// Sistem TTS gibi olay tabanlı motorlarda, kesilen bir cümlenin **geç
/// gelen** bitiş/iptal olayının yeni cümleye karışmasını önler.
///
/// Platform olayları sıralıdır: eski cümlenin iptali, yeni cümlenin
/// başlangıcından önce gelir. Bu yüzden yeni cümle "başladı" olayı gelene
/// kadar alınan bitiş/iptal olayları eskiye aittir ve yok sayılır.
class UtteranceSequencer {
  Completer<bool>? _current;
  bool _started = false;

  /// Yeni cümle için bekleme noktası; eski bekleyen varsa kesilmiş sayılır.
  Future<bool> begin() {
    cancelCurrent();
    final c = Completer<bool>();
    _current = c;
    _started = false;
    return c.future;
  }

  void onStart() {
    if (_current != null) _started = true;
  }

  /// Bitiş (`finished: true`) ya da iptal (`false`) olayı.
  void onTerminal({required bool finished}) {
    final c = _current;
    if (c == null || !_started) return; // önceki cümleye ait geç olay
    _current = null;
    if (!c.isCompleted) c.complete(finished);
  }

  void onError(Object error) {
    final c = _current;
    if (c == null) return;
    _current = null;
    if (!c.isCompleted) c.completeError(error);
  }

  /// Başlangıç olayı hiç gelmezse (bazı motorlar çok kısa metinde
  /// atlayabilir) sonraki terminal olayı kabul et.
  void assumeStarted() {
    if (_current != null) _started = true;
  }

  /// Bekleyen cümleyi "kesildi" olarak hemen tamamla.
  void cancelCurrent() {
    final c = _current;
    _current = null;
    _started = false;
    if (c != null && !c.isCompleted) c.complete(false);
  }

  bool get isWaiting => _current != null;
}

/// Bulut ses motorunu (Edge, OpenAI, ElevenLabs) sarar; motor hata verirse
/// ([UtteranceEngine.speak] istisna fırlatırsa) kalıcı olarak [fallback]'e
/// (cihazın kendi sesi) geçer ve aynı cümleyi onunla okur.
///
/// Gerekçe: Edge'in resmi olmayan uç noktası Ekim 2026'da 403 döndürmeye
/// başladı; anahtar bitince ya da ağ kopunca OpenAI/ElevenLabs da susuyordu.
/// Brifing artık sessizce durmuyor, cihaz sesiyle devam ediyor.
class FallbackEngine extends UtteranceEngine {
  FallbackEngine({
    required this.primary,
    required this.fallback,
    this.onFallback,
  });

  final UtteranceEngine primary;
  final UtteranceEngine fallback;

  /// Geçiş anında bir kez çağrılır (kullanıcıya bilgi vermek için).
  final void Function(Object error)? onFallback;

  bool _usingFallback = false;
  bool get usingFallback => _usingFallback;
  UtteranceEngine get _active => _usingFallback ? fallback : primary;

  @override
  Future<bool> speak(String text, {required double speed}) async {
    if (!_usingFallback) {
      try {
        return await primary.speak(text, speed: speed);
      } catch (e) {
        _usingFallback = true;
        await primary.interrupt();
        onFallback?.call(e);
      }
    }
    return fallback.speak(text, speed: speed);
  }

  @override
  Future<void> interrupt() => _active.interrupt();

  @override
  void prefetch(String text) {
    if (!_usingFallback) primary.prefetch(text);
  }

  @override
  bool get canChangeSpeedLive => _active.canChangeSpeedLive;
  @override
  Future<void> setLiveSpeed(double speed) => _active.setLiveSpeed(speed);

  @override
  bool get canPauseInPlace => _active.canPauseInPlace;
  @override
  Future<void> pauseInPlace() => _active.pauseInPlace();
  @override
  Future<void> resumeInPlace() => _active.resumeInPlace();

  @override
  bool get supportsPitch => _active.supportsPitch;
  @override
  Future<void> setPitch(double pitch) => _active.setPitch(pitch);

  @override
  Future<void> dispose() async {
    await primary.dispose();
    await fallback.dispose();
  }
}
