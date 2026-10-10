import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/repositories/edge_tts_service.dart';
import '../../data/repositories/elevenlabs_tts_service.dart';
import '../../data/repositories/openai_tts_service.dart';
import '../../providers/tts_settings_provider.dart';
import 'briefing_player.dart';
import 'utterance_engines.dart';

/// Kullanıcının TTS ayarlarına göre seslendirme motorunu kurar. Sesli
/// brifing ve haber detayındaki "Sesli özetle" aynı motorları kullanır.
class TtsEngineFactory {
  TtsEngineFactory({
    required FlutterTts systemTts,
    required AudioPlayer player,
    EdgeTtsService? edge,
    OpenAiTtsService? openai,
    ElevenLabsTtsService? elevenLabs,
  })  : _systemTts = systemTts,
        _player = player,
        _edge = edge ?? EdgeTtsService(),
        _openai = openai ?? OpenAiTtsService(),
        _elevenLabs = elevenLabs ?? ElevenLabsTtsService();

  final FlutterTts _systemTts;
  final AudioPlayer _player;
  final EdgeTtsService _edge;
  final OpenAiTtsService _openai;
  final ElevenLabsTtsService _elevenLabs;

  /// Motoru etkileyen ayarların imzası; değişince motor yeniden kurulur.
  static String keyFor(TtsSettingsProvider tts) => switch (tts.ttsEngine) {
        TtsEngineKind.system => 'system',
        TtsEngineKind.edge => 'edge|${tts.edgeTtsVoice}',
        TtsEngineKind.openai =>
          'openai|${tts.openaiTtsVoice}|${tts.openaiTtsModel}|'
              '${tts.openaiTtsKey.hashCode}',
        TtsEngineKind.elevenlabs =>
          'el|${tts.elevenLabsVoiceId}|${tts.elevenLabsModelId}|'
              '${tts.elevenLabsStability}|${tts.elevenLabsSimilarityBoost}|'
              '${tts.elevenLabsApiKey.hashCode}',
      };

  /// Bulut motorları [FallbackEngine] ile sarılır: hata verirlerse (Edge
  /// 403, eksik/geçersiz anahtar, ağ) cihazın sesine geçilir ve
  /// [onFallback] bir kez çağrılır.
  UtteranceEngine build(
    TtsSettingsProvider tts, {
    void Function(Object error)? onFallback,
  }) {
    final kind = tts.ttsEngine;
    if (kind == TtsEngineKind.system) return SystemTtsEngine(_systemTts);
    final UtteranceEngine cloud = switch (kind) {
      TtsEngineKind.edge => AudioFileEngine(
          player: _player,
          cacheVoice: tts.edgeTtsVoice,
          cacheModel: 'edge',
          synthesize: (text) =>
              _edge.synthesize(text: text, voice: tts.edgeTtsVoice),
        ),
      TtsEngineKind.openai => AudioFileEngine(
          player: _player,
          cacheVoice: tts.openaiTtsVoice,
          cacheModel: tts.openaiTtsModel,
          synthesize: (text) => _openai.synthesize(
            apiKey: tts.openaiTtsKey,
            text: text,
            voice: tts.openaiTtsVoice,
            model: tts.openaiTtsModel,
          ),
        ),
      _ => AudioFileEngine(
          player: _player,
          cacheVoice: tts.elevenLabsVoiceId,
          cacheModel: tts.elevenLabsModelId,
          synthesize: (text) => _elevenLabs.synthesize(
            apiKey: tts.elevenLabsApiKey,
            text: text,
            voiceId: tts.elevenLabsVoiceId,
            modelId: tts.elevenLabsModelId,
            stability: tts.elevenLabsStability,
            similarityBoost: tts.elevenLabsSimilarityBoost,
          ),
        ),
    };
    return FallbackEngine(
      primary: cloud,
      fallback: SystemTtsEngine(_systemTts),
      onFallback: onFallback,
    );
  }

  void close() => _elevenLabs.close();

  /// Hata mesajını kullanıcıya gösterilecek kısa biçime getirir.
  static String shortError(Object e) {
    final m = RegExp(r'HTTP status code: (\d+)').firstMatch('$e');
    if (m != null) return 'sunucu ${m.group(1)} döndü';
    final text = '$e'.replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }
}
