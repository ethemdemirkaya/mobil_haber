import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:pusula_news/core/tts/briefing_player.dart';

/// Testin elle bitirdiği cümlelerle çalışan sahte motor.
class FakeEngine extends UtteranceEngine {
  FakeEngine({this.live = false});

  final bool live;
  final List<String> spoken = [];
  final List<double> speeds = [];
  Completer<bool>? _current;
  double liveSpeed = 1.0;
  bool pausedInPlace = false;

  @override
  bool get canChangeSpeedLive => live;
  @override
  bool get canPauseInPlace => live;

  @override
  Future<bool> speak(String text, {required double speed}) {
    spoken.add(text);
    speeds.add(speed);
    final c = Completer<bool>();
    _current = c;
    return c.future;
  }

  /// Çalan cümleyi doğal olarak bitir.
  Future<void> finishCurrent() async {
    final c = _current;
    _current = null;
    c?.complete(true);
    await pump();
  }

  @override
  Future<void> interrupt() async {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete(false);
  }

  @override
  Future<void> setLiveSpeed(double speed) async => liveSpeed = speed;
  @override
  Future<void> pauseInPlace() async => pausedInPlace = true;
  @override
  Future<void> resumeInPlace() async => pausedInPlace = false;
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

const _lines = ['bir', 'iki', 'üç', 'dört', 'beş'];

Future<(BriefingPlayer, FakeEngine)> setup({bool live = false}) async {
  final engine = FakeEngine(live: live);
  final player = BriefingPlayer(engine: engine);
  await player.load(_lines);
  return (player, engine);
}

void main() {
  test('cümleleri sırayla okur ve sonunda durur', () async {
    final (player, engine) = await setup();
    unawaited(player.play());
    await pump();
    for (var i = 0; i < _lines.length; i++) {
      expect(player.index, i);
      await engine.finishCurrent();
    }
    expect(engine.spoken, _lines);
    expect(player.status, BriefingPlaybackStatus.idle);
  });

  test('sistem TTS: hız değişince aynı cümleden devam eder (sona/başa '
      'sarmaz)', () async {
    final (player, engine) = await setup();
    unawaited(player.play());
    await pump();
    await engine.finishCurrent(); // "bir" bitti
    await engine.finishCurrent(); // "iki" bitti → "üç" çalıyor
    expect(player.index, 2);

    await player.setSpeed(1.5);
    await pump();
    expect(player.index, 2);
    expect(player.isPlaying, isTrue);
    expect(engine.spoken.last, 'üç');
    expect(engine.speeds.last, 1.5);

    await engine.finishCurrent();
    expect(engine.spoken.last, 'dört');
  });

  test('MP3 motoru: hız cümle kesilmeden anında değişir', () async {
    final (player, engine) = await setup(live: true);
    unawaited(player.play());
    await pump();
    await engine.finishCurrent();
    await player.setSpeed(2.0);
    expect(engine.liveSpeed, 2.0);
    expect(engine.spoken, ['bir', 'iki'], reason: 'yeniden okuma yok');
    expect(player.index, 1);
  });

  test('çalarken ileri sarma hedef cümleden devam eder', () async {
    final (player, engine) = await setup();
    unawaited(player.play());
    await pump();
    await player.seek(3);
    await pump();
    expect(player.index, 3);
    expect(engine.spoken.last, 'dört');
    expect(player.isPlaying, isTrue);
  });

  test('sonraki/önceki cümle konumu korur (kilit ekranı hatası)', () async {
    final (player, engine) = await setup();
    unawaited(player.play());
    await pump();
    await engine.finishCurrent(); // index 1
    await player.skipNext();
    await pump();
    expect(player.index, 2);
    await player.skipPrevious();
    await pump();
    expect(player.index, 1);
    expect(engine.spoken.last, 'iki');
  });

  test('durmuşken ileri sarınca oynat oradan başlar', () async {
    final (player, engine) = await setup();
    await player.seek(2);
    expect(player.isPaused, isTrue);
    unawaited(player.play());
    await pump();
    expect(engine.spoken, ['üç']);
  });

  test('duraklat/devam: sistem TTS aynı cümleyi baştan okur, başa '
      'dönmez', () async {
    final (player, engine) = await setup();
    unawaited(player.play());
    await pump();
    await engine.finishCurrent(); // "iki" çalıyor
    await player.pause();
    await pump();
    expect(player.isPaused, isTrue);
    unawaited(player.play());
    await pump();
    expect(player.index, 1);
    expect(engine.spoken, ['bir', 'iki', 'iki']);
  });

  test('duraklat/devam: MP3 motoru cümle ortasından devam eder', () async {
    final (player, engine) = await setup(live: true);
    unawaited(player.play());
    await pump();
    await player.pause();
    expect(engine.pausedInPlace, isTrue);
    await player.play();
    expect(engine.pausedInPlace, isFalse);
    expect(engine.spoken, ['bir'], reason: 'cümle yeniden başlamadı');
    await engine.finishCurrent();
    expect(engine.spoken.last, 'iki');
  });

  test('durdur başa alır; sona gelindiyse oynat baştan başlar', () async {
    final (player, engine) = await setup();
    unawaited(player.play());
    await pump();
    await engine.finishCurrent();
    await player.stop();
    expect(player.index, 0);
    expect(player.status, BriefingPlaybackStatus.idle);
  });

  test('motor hatası çalmayı duraklatır, konum korunur', () async {
    final engine = _ThrowingEngine();
    final player = BriefingPlayer(engine: engine);
    await player.load(_lines);
    await player.play();
    await pump();
    expect(player.error, isNotNull);
    expect(player.isPaused, isTrue);
    expect(player.index, 0);
  });

  test('bulut motoru hata verince cihaz sesine geçip aynı cümleden sürer',
      () async {
    final fallback = FakeEngine();
    Object? reported;
    final engine = FallbackEngine(
      primary: _ThrowingEngine(),
      fallback: fallback,
      onFallback: (e) => reported = e,
    );
    final player = BriefingPlayer(engine: engine);
    await player.load(_lines);
    unawaited(player.play());
    await pump();
    expect(reported, isNotNull);
    expect(engine.usingFallback, isTrue);
    expect(player.error, isNull, reason: 'kullanıcı oynatması kesilmedi');
    expect(fallback.spoken, ['bir']);
    await fallback.finishCurrent();
    expect(fallback.spoken, ['bir', 'iki']);
  });

  group('UtteranceSequencer', () {
    test('yeni cümle başlamadan gelen geç iptal olayını yok sayar', () async {
      final seq = UtteranceSequencer();
      final first = seq.begin();
      seq.onStart();
      // Hız değişti: ilk cümle kesildi, ikincisi istendi.
      final second = seq.begin();
      expect(await first, isFalse);
      // İlk cümlenin geç gelen iptal olayı:
      seq.onTerminal(finished: false);
      var secondDone = false;
      unawaited(second.then((_) => secondDone = true));
      await pump();
      expect(secondDone, isFalse, reason: 'geç olay yeni cümleyi bitirmemeli');
      seq.onStart();
      seq.onTerminal(finished: true);
      expect(await second, isTrue);
    });
  });
}

class _ThrowingEngine extends UtteranceEngine {
  @override
  Future<bool> speak(String text, {required double speed}) async =>
      throw Exception('ağ hatası');
  @override
  Future<void> interrupt() async {}
}
