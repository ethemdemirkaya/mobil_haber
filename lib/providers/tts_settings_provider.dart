import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sesli brifing okumak için hangi motorun kullanılacağı.
enum TtsEngineKind {
  /// flutter_tts: cihazın native TTS'i. Hızlı, ücretsiz, çevrimdışı.
  /// Türkçe ses kalitesi cihaza göre değişir.
  system,

  /// OpenAI `audio/speech`: yüksek kaliteli MP3, parametrik ses seçimi.
  /// Kullanıcı kendi OpenAI API anahtarını girer (OpenRouter'dan ayrı).
  /// Maliyet: \$15/1M karakter (~brifing başına \$0.015).
  openai,

  /// ElevenLabs `text-to-speech`: son derece doğal ses kalitesi.
  /// Multilingual v2 ile Türkçe dahil 29 dil destekler.
  /// Kullanıcı kendi ElevenLabs API anahtarını girer.
  /// Maliyet: ~\$0.30/1K karakter (~brifing başına \$0.03–0.05).
  elevenlabs,

  /// Microsoft Edge TTS: ücretsiz, API anahtarı gerektirmez.
  /// WebSocket protokolüyle speech.platform.bing.com üzerinden çalışır.
  /// Türkçe: EmelNeural (kadın) / AhmetNeural (erkek).
  edge,
}

extension TtsEngineKindLabel on TtsEngineKind {
  String get label => switch (this) {
    TtsEngineKind.system => 'Sistem TTS (varsayılan)',
    TtsEngineKind.openai => 'OpenAI TTS (yüksek kalite)',
    TtsEngineKind.elevenlabs => 'ElevenLabs (en doğal ses)',
    TtsEngineKind.edge => 'Edge TTS (ücretsiz, doğal)',
  };

  String get description => switch (this) {
    TtsEngineKind.system =>
      'Cihazın yerleşik konuşma motoru — '
          'ücretsiz ve çevrimdışı, kalite cihaza bağlı.',
    TtsEngineKind.openai =>
      'OpenAI sunucularında üretilen MP3, '
          'doğal ses. OpenAI API anahtarı + ücret gerekir.',
    TtsEngineKind.elevenlabs =>
      'ElevenLabs AI sesleri — son derece doğal, '
          'Türkçe multilingual v2 modeli. ElevenLabs API anahtarı gerekir.',
    TtsEngineKind.edge =>
      'Microsoft Edge TTS — ücretsiz, API anahtarı gerektirmez. '
          'Türkçe: Emel (kadın) veya Ahmet (erkek) sesi.',
  };
}

/// Sesli okuma (TTS) motoru ve ses ayarları.
///
/// Eskiden `AiSettingsProvider` içindeydi; o sınıf AI ayarları, TTS
/// ayarları ve üç ayrı cache'i birlikte yönetiyordu. Ayar anahtarları
/// (SharedPreferences) değişmedi — kullanıcının kayıtlı tercihleri korunur.
class TtsSettingsProvider extends ChangeNotifier {
  TtsSettingsProvider() {
    _load();
  }

  final Completer<void> _initCompleter = Completer<void>();

  /// Kayıtlı tercihler yüklendiğinde tamamlanır.
  Future<void> get whenInitialized => _initCompleter.future;

  // ─── TTS (sesli okuma) ───
  TtsEngineKind _ttsEngine = TtsEngineKind.system;
  String _openaiTtsKey = '';
  String _openaiTtsVoice = 'nova';
  String _openaiTtsModel = 'tts-1';

  // ─── Edge TTS ───
  String _edgeTtsVoice = 'tr-TR-EmelNeural';

  // ─── ElevenLabs TTS ───
  String _elevenLabsApiKey = '';
  String _elevenLabsVoiceId = 'pNInz6obpgDQGcFmaJgB'; // Adam
  String _elevenLabsModelId = 'eleven_multilingual_v2';
  double _elevenLabsStability = 0.45;
  double _elevenLabsSimilarityBoost = 0.75;

  static const String _prefsTtsEngine = 'pref_ai_tts_engine';
  static const String _prefsOpenaiTtsKey = 'pref_ai_openai_tts_key';
  static const String _prefsOpenaiTtsVoice = 'pref_ai_openai_tts_voice';
  static const String _prefsOpenaiTtsModel = 'pref_ai_openai_tts_model';
  static const String _prefsEdgeVoice = 'edge_tts_voice';
  static const String _prefsElKey = 'elevenlabs_key';
  static const String _prefsElVoice = 'elevenlabs_voice';
  static const String _prefsElModel = 'elevenlabs_model';
  static const String _prefsElStability = 'elevenlabs_stability';
  static const String _prefsElSimilarity = 'elevenlabs_similarity';

  // ─── TTS getters ───
  TtsEngineKind get ttsEngine => _ttsEngine;
  String get openaiTtsKey => _openaiTtsKey;
  bool get hasOpenaiTtsKey => _openaiTtsKey.isNotEmpty;
  String get openaiTtsVoice => _openaiTtsVoice;
  String get openaiTtsModel => _openaiTtsModel;

  // ─── ElevenLabs getters ───
  String get elevenLabsApiKey => _elevenLabsApiKey;
  bool get hasElevenLabsKey => _elevenLabsApiKey.isNotEmpty;
  String get elevenLabsVoiceId => _elevenLabsVoiceId;
  String get elevenLabsModelId => _elevenLabsModelId;
  double get elevenLabsStability => _elevenLabsStability;
  double get elevenLabsSimilarityBoost => _elevenLabsSimilarityBoost;

  // ─── Edge TTS getters ───
  String get edgeTtsVoice => _edgeTtsVoice;

  /// Seçili TTS motoru kullanılabilir durumda mı? OpenAI/ElevenLabs
  /// seçildiyse ilgili anahtar girilmiş olmalı. Edge ve System ücretsiz.
  bool get isTtsEngineUsable {
    switch (_ttsEngine) {
      case TtsEngineKind.system:
      case TtsEngineKind.edge:
        return true;
      case TtsEngineKind.elevenlabs:
        return _elevenLabsApiKey.isNotEmpty;
      case TtsEngineKind.openai:
        return _openaiTtsKey.isNotEmpty;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ttsEngineId =
        prefs.getString(_prefsTtsEngine) ?? TtsEngineKind.system.name;
    _ttsEngine = TtsEngineKind.values.firstWhere(
      (e) => e.name == ttsEngineId,
      orElse: () => TtsEngineKind.system,
    );
    _openaiTtsKey = prefs.getString(_prefsOpenaiTtsKey) ?? '';
    _openaiTtsVoice = prefs.getString(_prefsOpenaiTtsVoice) ?? 'nova';
    _openaiTtsModel = prefs.getString(_prefsOpenaiTtsModel) ?? 'tts-1';

    _edgeTtsVoice = prefs.getString(_prefsEdgeVoice) ?? 'tr-TR-EmelNeural';

    _elevenLabsApiKey = prefs.getString(_prefsElKey) ?? '';
    _elevenLabsVoiceId =
        prefs.getString(_prefsElVoice) ?? 'pNInz6obpgDQGcFmaJgB';
    _elevenLabsModelId =
        prefs.getString(_prefsElModel) ?? 'eleven_multilingual_v2';
    _elevenLabsStability = prefs.getDouble(_prefsElStability) ?? 0.45;
    _elevenLabsSimilarityBoost = prefs.getDouble(_prefsElSimilarity) ?? 0.75;

    if (!_initCompleter.isCompleted) _initCompleter.complete();
    notifyListeners();
  }

  // ─────────── TTS setters ───────────
  Future<void> setTtsEngine(TtsEngineKind kind) async {
    if (_ttsEngine == kind) return;
    _ttsEngine = kind;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTtsEngine, kind.name);
  }

  Future<void> setOpenaiTtsKey(String value) async {
    final trimmed = value.trim();
    if (_openaiTtsKey == trimmed) return;
    _openaiTtsKey = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsOpenaiTtsKey);
    } else {
      await prefs.setString(_prefsOpenaiTtsKey, trimmed);
    }
  }

  Future<void> setOpenaiTtsVoice(String voice) async {
    if (_openaiTtsVoice == voice) return;
    _openaiTtsVoice = voice;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOpenaiTtsVoice, voice);
  }

  Future<void> setOpenaiTtsModel(String model) async {
    if (_openaiTtsModel == model) return;
    _openaiTtsModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsOpenaiTtsModel, model);
  }

  // ─────────── ElevenLabs TTS setters ───────────
  Future<void> setElevenLabsApiKey(String value) async {
    final trimmed = value.trim();
    if (_elevenLabsApiKey == trimmed) return;
    _elevenLabsApiKey = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsElKey);
    } else {
      await prefs.setString(_prefsElKey, trimmed);
    }
  }

  Future<void> setElevenLabsVoiceId(String voiceId) async {
    if (_elevenLabsVoiceId == voiceId) return;
    _elevenLabsVoiceId = voiceId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsElVoice, voiceId);
  }

  Future<void> setElevenLabsModelId(String modelId) async {
    if (_elevenLabsModelId == modelId) return;
    _elevenLabsModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsElModel, modelId);
  }

  Future<void> setElevenLabsStability(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (_elevenLabsStability == clamped) return;
    _elevenLabsStability = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsElStability, clamped);
  }

  Future<void> setElevenLabsSimilarityBoost(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (_elevenLabsSimilarityBoost == clamped) return;
    _elevenLabsSimilarityBoost = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsElSimilarity, clamped);
  }

  // ─────────── Edge TTS setter ───────────
  Future<void> setEdgeTtsVoice(String voice) async {
    if (_edgeTtsVoice == voice) return;
    _edgeTtsVoice = voice;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsEdgeVoice, voice);
  }
}
