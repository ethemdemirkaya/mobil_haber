import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ai/openrouter_client.dart';
import '../data/models/article.dart';
import '../data/models/bias_report.dart';
import '../data/repositories/ai_summary_service.dart';
import '../data/repositories/openrouter_models_repository.dart';

/// OpenRouter modeli için "preset" tanımları.
///
/// `id` doğrudan OpenRouter'ın model id'si — `provider/model-name` formatı.
/// Liste güncel tutulmazsa bile kullanıcı `customModelId` üzerinden istediği
/// model id'yi yazabilir.
class AiModelPreset {
  const AiModelPreset({
    required this.id,
    required this.label,
    required this.description,
    this.tier = AiModelTier.balanced,
  });

  final String id;
  final String label;
  final String description;
  final AiModelTier tier;
}

enum AiModelTier { fast, balanced, premium, free }

/// API anahtarının kaynağı — UI bunu rozet olarak göstermek isteyebilir.
enum AiKeySource {
  /// Hiç anahtar yok (build-time default da yok, kullanıcı da girmemiş).
  none,

  /// `--dart-define=OPENROUTER_API_KEY=...` ile gömülmüş build-time anahtar.
  builtIn,

  /// Kullanıcının Ayarlar'dan girdiği kişisel anahtar.
  userProvided,
}

/// Kullanıcının HANGİ anahtarı kullanmak istediğine dair tercihi.
/// Bu kayıttan bağımsız olarak hem env-embedded hem user-entered key
/// saklı kalır; mode hangisinin aktif olacağına karar verir.
enum ApiKeyMode {
  /// Uygulama içinde gömülü (`.env.json`'daki) anahtar — varsayılan.
  builtIn,

  /// Kullanıcının Ayarlar'dan girdiği kişisel anahtar.
  userProvided,
}

extension ApiKeyModeLabel on ApiKeyMode {
  String get label => switch (this) {
        ApiKeyMode.builtIn => 'Varsayılan',
        ApiKeyMode.userProvided => 'Kendi anahtarım',
      };

  String get description => switch (this) {
        ApiKeyMode.builtIn => 'Pusula\'nın yerleşik OpenRouter anahtarı '
            '(uygulamayla birlikte gelir).',
        ApiKeyMode.userProvided =>
          'Kişisel OpenRouter anahtarın — kendi kullanım limitin, '
              'kendi faturalandırman.',
      };
}

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
        TtsEngineKind.system => 'Cihazın yerleşik konuşma motoru — '
            'ücretsiz ve çevrimdışı, kalite cihaza bağlı.',
        TtsEngineKind.openai => 'OpenAI sunucularında üretilen MP3, '
            'doğal ses. OpenAI API anahtarı + ücret gerekir.',
        TtsEngineKind.elevenlabs =>
          'ElevenLabs AI sesleri — son derece doğal, '
              'Türkçe multilingual v2 modeli. ElevenLabs API anahtarı gerekir.',
        TtsEngineKind.edge =>
          'Microsoft Edge TTS — ücretsiz, API anahtarı gerektirmez. '
              'Türkçe: Emel (kadın) veya Ahmet (erkek) sesi.',
      };
}

extension AiModelTierLabel on AiModelTier {
  String get label => switch (this) {
        AiModelTier.fast => 'Hızlı / Ucuz',
        AiModelTier.balanced => 'Dengeli',
        AiModelTier.premium => 'Yüksek kalite',
        AiModelTier.free => 'Ücretsiz',
      };
}

/// Yapay zeka özetleme ayarları + cache provider'ı.
///
/// SharedPreferences ile kalıcı:
///   - `pref_ai_enabled` (bool)
///   - `pref_ai_api_key`  (String — kullanıcı kendi kişisel cihazında saklar)
///   - `pref_ai_model`    (String — OpenRouter model id)
///   - `pref_ai_cache`    (`Map<String, String>` — articleId → özet)
///
/// **Güvenlik notu:** API anahtarı cihazın SharedPreferences'ında
/// düz metin saklanır. Production sürümde Keychain/Keystore (örn.
/// `flutter_secure_storage`) kullanılmalı. Demo aşamada bu yeterli.
class AiSettingsProvider extends ChangeNotifier {
  AiSettingsProvider({
    AiSummaryService? service,
    OpenRouterModelsRepository? modelsRepo,
  })  : _service = service ?? AiSummaryService(),
        _modelsRepo = modelsRepo ?? OpenRouterModelsRepository() {
    _load();
  }

  final AiSummaryService _service;
  final OpenRouterModelsRepository _modelsRepo;

  // Live OpenRouter model listesi
  List<OpenRouterModel> _availableModels = const [];
  bool _modelsLoading = false;
  String? _modelsError;

  bool _initialized = false;
  // SharedPreferences yüklemesi tamamlanınca complete edilir. Beklemek
  // isteyen ekranlar (ör. DailyBriefingScreen) `whenInitialized`'i await
  // eder — polling yerine event-driven bekleme.
  final Completer<void> _initCompleter = Completer<void>();
  bool _enabled = false;
  String _apiKey = '';
  String _modelId = defaultModelId;

  /// Hangi anahtar (mode) aktif kullanılacak. Default builtIn — env
  /// dosyasındaki anahtar varsa onu kullanır. User explicit "kendi
  /// anahtarım" derse o aktif olur.
  ApiKeyMode _apiKeyMode = ApiKeyMode.builtIn;

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

  // ─── First-run banner ───
  /// Build-time anahtar ile gelen yeni kullanıcı için "AI hazır" bildirimi
  /// bir kez gösterildi mi?
  bool _firstRunNoticeShown = false;

  /// articleId → özet metni
  final Map<String, String> _cache = <String, String>{};

  /// articleId → bias raporu (kalıcı, JSON olarak SharedPreferences).
  final Map<String, BiasReport> _biasCache = <String, BiasReport>{};

  /// "${articleId}::${question}" → cevap. In-memory only — kullanıcı her
  /// soru her oturumda taze çağrılsın diye.
  final Map<String, String> _qaCache = <String, String>{};

  /// Aktif çağrı durumu — UI loading indicator için. Aynı anda 1 çağrı.
  String? _loadingArticleId;
  String? _loadingBiasId;
  String? _loadingQaId;
  String? _lastError;

  static const String _prefsEnabled = 'pref_ai_enabled';
  static const String _prefsKey = 'pref_ai_api_key';
  static const String _prefsKeyMode = 'pref_ai_key_mode';
  static const String _prefsModel = 'pref_ai_model';
  static const String _prefsCache = 'pref_ai_cache';
  static const String _prefsBiasCache = 'pref_ai_bias_cache';
  static const String _prefsTtsEngine = 'pref_ai_tts_engine';
  static const String _prefsOpenaiTtsKey = 'pref_ai_openai_tts_key';
  static const String _prefsOpenaiTtsVoice = 'pref_ai_openai_tts_voice';
  static const String _prefsOpenaiTtsModel = 'pref_ai_openai_tts_model';
  static const String _prefsFirstRunNotice = 'pref_ai_first_run_notice';
  static const String _prefsEdgeVoice = 'edge_tts_voice';
  static const String _prefsElKey = 'elevenlabs_key';
  static const String _prefsElVoice = 'elevenlabs_voice';
  static const String _prefsElModel = 'elevenlabs_model';
  static const String _prefsElStability = 'elevenlabs_stability';
  static const String _prefsElSimilarity = 'elevenlabs_similarity';

  /// Default — OpenAI'ın açık-ağırlıklı 20B modeli, OpenRouter'da
  /// :free tier'da rate-limit ile ücretsiz. Yedek olarak Gemini 2.0 Flash
  /// free de mevcut (presets[1]).
  static const String defaultModelId = 'openai/gpt-oss-20b:free';

  /// Kullanıcıya sunulan hazır model listesi. ID'ler OpenRouter'ın resmi
  /// model id'leri ile eşleşmelidir. Listede olmayan modelleri kullanmak
  /// için "Diğer" seçilip elle id girilebilir.
  ///
  /// Sıralama: önce ücretsiz seçenekler (yeni kullanıcı için sıfır maliyet),
  /// sonra ucuz hızlılar, sonra premium.
  static const List<AiModelPreset> presets = [
    AiModelPreset(
      id: 'openai/gpt-oss-20b:free',
      label: 'GPT OSS 20B (free)',
      description:
          'OpenAI açık-ağırlıklı 20B — varsayılan, ücretsiz katmanda kullanım.',
      tier: AiModelTier.free,
    ),
    AiModelPreset(
      id: 'google/gemini-2.0-flash-exp:free',
      label: 'Gemini 2.0 Flash (free)',
      description: 'Google — ücretsiz, hızlı, geniş context (yedek).',
      tier: AiModelTier.free,
    ),
    AiModelPreset(
      id: 'anthropic/claude-3.5-haiku',
      label: 'Claude 3.5 Haiku',
      description: 'Anthropic — hızlı, ucuz, özet için ideal (~\$0.0005/makale).',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'openai/gpt-4o-mini',
      label: 'GPT-4o mini',
      description: 'OpenAI — Haiku\'ya rakip, güçlü Türkçe.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'google/gemini-flash-1.5',
      label: 'Gemini 1.5 Flash',
      description: 'Google — çok hızlı, geniş context.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'deepseek/deepseek-chat',
      label: 'DeepSeek Chat',
      description: 'DeepSeek — düşük maliyet, iyi performans.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'meta-llama/llama-3.1-70b-instruct',
      label: 'Llama 3.1 70B',
      description: 'Meta — açık ağırlıklı, dengeli.',
      tier: AiModelTier.balanced,
    ),
    AiModelPreset(
      id: 'anthropic/claude-3.5-sonnet',
      label: 'Claude 3.5 Sonnet',
      description: 'Anthropic — daha tutarlı, biraz daha pahalı.',
      tier: AiModelTier.balanced,
    ),
    AiModelPreset(
      id: 'openai/gpt-4o',
      label: 'GPT-4o',
      description: 'OpenAI — yüksek kalite, daha pahalı.',
      tier: AiModelTier.premium,
    ),
  ];

  // ─────────── Getters ───────────
  bool get initialized => _initialized;

  /// SharedPreferences yüklemesi tamamlandığında resolve olan future.
  /// Polling alternatifi — splash veya brifing init bunu bekler.
  Future<void> get whenInitialized => _initCompleter.future;
  bool get enabled => _enabled;

  /// Kullanıcının Ayarlar'dan girdiği anahtar. Build-time default'tan ayrı.
  String get apiKey => _apiKey;
  String get modelId => _modelId;

  /// Kullanıcı kendi anahtarını girmiş mi?
  bool get hasUserApiKey => _apiKey.isNotEmpty;

  /// Build-time'da `--dart-define=OPENROUTER_API_KEY=...` ile bir default
  /// gömülmüş mü? Settings ekranında "kendi keyini girmek zorunda değilsin"
  /// hint'i için.
  bool get hasBuiltInKey => OpenRouterClient.hasBuiltInKey;

  /// Kullanıcının hangi modu aktif tercih ettiği.
  ApiKeyMode get apiKeyMode => _apiKeyMode;

  /// API çağrılarında kullanılacak gerçek anahtar. Mode'a göre seçer:
  ///   - userProvided: kullanıcının girdiği anahtar (boş ise boş döner)
  ///   - builtIn: build-time gömülü anahtar (boş ise boş döner)
  /// Boş dönerse `isReady` false olur.
  String get effectiveApiKey {
    return _apiKeyMode == ApiKeyMode.userProvided
        ? _apiKey
        : OpenRouterClient.defaultApiKey;
  }

  /// Etkin anahtarın kaynağı — UI rozeti için. Aktif mode'a göre değişir.
  AiKeySource get keySource {
    if (effectiveApiKey.isEmpty) return AiKeySource.none;
    return _apiKeyMode == ApiKeyMode.userProvided
        ? AiKeySource.userProvided
        : AiKeySource.builtIn;
  }

  bool get hasAnyKey => effectiveApiKey.isNotEmpty;

  /// Aktif modu kullanmak için gerekli anahtar var mı?
  /// userProvided modunda kullanıcı keyi olmalı, builtIn'de env keyi.
  bool get isModeUsable {
    return _apiKeyMode == ApiKeyMode.userProvided
        ? _apiKey.isNotEmpty
        : OpenRouterClient.hasBuiltInKey;
  }

  /// Eski API uyumluluğu — UI bazı yerlerde `hasApiKey` çağırıyor olabilir.
  bool get hasApiKey => hasAnyKey;

  /// Aktif modelin görünen adı — hazır listedeyse label, değilse id.
  String get currentModelLabel {
    for (final p in presets) {
      if (p.id == _modelId) return p.label;
    }
    return _modelId.isEmpty ? 'Seçilmedi' : _modelId;
  }

  String? get loadingArticleId => _loadingArticleId;
  bool isLoadingFor(String articleId) => _loadingArticleId == articleId;
  String? get lastError => _lastError;

  // ─── Live OpenRouter modeller ───
  List<OpenRouterModel> get availableModels => _availableModels;
  List<OpenRouterModel> get availableFreeModels =>
      _availableModels.where((m) => m.isFree).toList(growable: false);
  bool get modelsLoading => _modelsLoading;
  String? get modelsError => _modelsError;
  bool get hasFetchedModels => _availableModels.isNotEmpty;

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

  // ─── First-run notice ───
  /// Sadece şu an gösterilmeli mi? — built-in key VAR + henüz görmemiş.
  bool get shouldShowFirstRunNotice =>
      !_firstRunNoticeShown && keySource == AiKeySource.builtIn;

  bool get firstRunNoticeShown => _firstRunNoticeShown;

  /// Belirli bir makale için cache'lenmiş özet (yoksa null).
  String? cachedSummary(String articleId) => _cache[articleId];

  /// Cache'lenmiş bias raporu — yoksa null. Yeniden çağırma ücret
  /// üretmesin diye kalıcı cache'liyoruz.
  BiasReport? cachedBias(String articleId) => _biasCache[articleId];

  /// In-memory Q&A cache. Aynı oturumda tekrar açılırsa hızlıca dönsün
  /// diye. Kalıcı değil — token israfını önlemek için disk'e yazmıyoruz.
  String? cachedAnswer(String articleId, String question) =>
      _qaCache['$articleId::${question.trim()}'];

  /// Aktif bias çağrısının makale id'si — UI loading state.
  String? get loadingBiasId => _loadingBiasId;

  /// Aktif Q&A çağrısının makale id'si — UI loading state.
  String? get loadingQaId => _loadingQaId;

  /// Kullanıcıya bu makale için "Özetle" butonu gösterilmeli mi?
  bool isReady() => _enabled && hasAnyKey && _modelId.isNotEmpty;

  // ─────────── Persistence ───────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Build-time bir default key gömülmüşse uygulamayı varsayılan olarak
    // "etkin" kabul ediyoruz — kullanıcının elle açmasına gerek kalmasın.
    // Aksi halde kullanıcı kendi anahtarını girene kadar pasif başlasın.
    _enabled = prefs.getBool(_prefsEnabled) ??
        OpenRouterClient.hasBuiltInKey;
    _apiKey = prefs.getString(_prefsKey) ?? '';
    _modelId = prefs.getString(_prefsModel) ?? defaultModelId;

    // ApiKeyMode default kararı:
    //   - Kayıtlı bir tercih varsa onu yükle.
    //   - Yoksa: build-time anahtar varsa builtIn (sıfır kurulumla çalışsın);
    //     yoksa user'ın anahtarı zaten varsa userProvided; ikisi de yoksa
    //     builtIn (kullanıcı birini girince UI mode değiştirsin diye).
    final storedMode = prefs.getString(_prefsKeyMode);
    if (storedMode != null) {
      _apiKeyMode = ApiKeyMode.values.firstWhere(
        (m) => m.name == storedMode,
        orElse: () => ApiKeyMode.builtIn,
      );
    } else {
      _apiKeyMode = OpenRouterClient.hasBuiltInKey
          ? ApiKeyMode.builtIn
          : (_apiKey.isNotEmpty
              ? ApiKeyMode.userProvided
              : ApiKeyMode.builtIn);
    }

    // TTS tercihleri
    final ttsEngineId =
        prefs.getString(_prefsTtsEngine) ?? TtsEngineKind.system.name;
    _ttsEngine = TtsEngineKind.values.firstWhere(
      (e) => e.name == ttsEngineId,
      orElse: () => TtsEngineKind.system,
    );
    _openaiTtsKey = prefs.getString(_prefsOpenaiTtsKey) ?? '';
    _openaiTtsVoice = prefs.getString(_prefsOpenaiTtsVoice) ?? 'nova';
    _openaiTtsModel = prefs.getString(_prefsOpenaiTtsModel) ?? 'tts-1';

    _edgeTtsVoice =
        prefs.getString(_prefsEdgeVoice) ?? 'tr-TR-EmelNeural';

    _elevenLabsApiKey = prefs.getString(_prefsElKey) ?? '';
    _elevenLabsVoiceId =
        prefs.getString(_prefsElVoice) ?? 'pNInz6obpgDQGcFmaJgB';
    _elevenLabsModelId =
        prefs.getString(_prefsElModel) ?? 'eleven_multilingual_v2';
    _elevenLabsStability = prefs.getDouble(_prefsElStability) ?? 0.45;
    _elevenLabsSimilarityBoost =
        prefs.getDouble(_prefsElSimilarity) ?? 0.75;

    _firstRunNoticeShown = prefs.getBool(_prefsFirstRunNotice) ?? false;

    final raw = prefs.getString(_prefsCache);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cache.clear();
          decoded.forEach((k, v) {
            if (k is String && v is String) _cache[k] = v;
          });
        }
      } catch (_) {
        // Bozuk cache: yok say.
      }
    }
    final biasRaw = prefs.getString(_prefsBiasCache);
    if (biasRaw != null && biasRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(biasRaw);
        if (decoded is Map) {
          _biasCache.clear();
          decoded.forEach((k, v) {
            if (k is String) {
              final report = BiasReport.tryParse(v);
              if (report != null) _biasCache[k] = report;
            }
          });
        }
      } catch (_) {
        // Bozuk cache: yok say.
      }
    }
    _initialized = true;
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

  // ─────────── Live model listesi ───────────
  /// OpenRouter'dan tüm modelleri canlı çeker. UI önce hazır liste varsa
  /// onu gösterir, sonra sessizce yenisini ister.
  Future<void> loadOpenRouterModels({bool forceRefresh = false}) async {
    if (_modelsLoading) return;
    _modelsLoading = true;
    _modelsError = null;
    notifyListeners();
    try {
      _availableModels =
          await _modelsRepo.fetchAll(forceRefresh: forceRefresh);
    } catch (e) {
      _modelsError = 'Model listesi alınamadı: $e';
    } finally {
      _modelsLoading = false;
      notifyListeners();
    }
  }

  /// Şu an seçili modelin id'si, fetch edilen listede mevcut mu?
  /// Değilse — model expired/retired olmuş demektir; UI bir uyarı gösterir.
  bool get isCurrentModelValid {
    if (_availableModels.isEmpty) return true; // henüz fetch yok
    return _availableModels.any((m) => m.id == _modelId);
  }

  // ─────────── First-run notice ───────────
  Future<void> markFirstRunNoticeSeen() async {
    if (_firstRunNoticeShown) return;
    _firstRunNoticeShown = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsFirstRunNotice, true);
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCache, jsonEncode(_cache));
  }

  Future<void> _persistBiasCache() async {
    final prefs = await SharedPreferences.getInstance();
    final m = <String, Object?>{};
    _biasCache.forEach((k, v) => m[k] = v.toJson());
    await prefs.setString(_prefsBiasCache, jsonEncode(m));
  }

  // ─────────── Setters ───────────
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabled, value);
  }

  Future<void> setApiKey(String value) async {
    final trimmed = value.trim();
    if (_apiKey == trimmed) return;
    _apiKey = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, trimmed);
    }
  }

  /// Aktif anahtar modunu değiştir. UI segmented button'dan çağrılır.
  /// Kullanıcı `userProvided`'a geçerken anahtarı boşsa effectiveApiKey
  /// boş döner — UI bunu uyarı banner'ı ile gösterir.
  Future<void> setApiKeyMode(ApiKeyMode mode) async {
    if (_apiKeyMode == mode) return;
    _apiKeyMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyMode, mode.name);
  }

  Future<void> setModelId(String value) async {
    final trimmed = value.trim();
    if (_modelId == trimmed || trimmed.isEmpty) return;
    _modelId = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsModel, trimmed);
  }

  Future<void> clearCache() async {
    if (_cache.isEmpty) return;
    _cache.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCache);
  }

  // ─────────── Actions ───────────

  /// Verilen makaleyi özetler. Cache'te varsa onu döner, yoksa OpenRouter
  /// çağrısı yapar ve cache'e yazar. UI Consumer ile listener'ı izlediği
  /// için ek dönüş gerekmiyor — `cachedSummary(article.id)` ile okunabilir.
  ///
  /// Hata durumunda `lastError` set edilir, exception fırlatılmaz —
  /// UI bunu banner'da gösterir.
  Future<void> summarize(Article article) async {
    if (!isReady()) {
      _lastError =
          'Yapay zeka kapalı veya API anahtarı/model eksik — Ayarlar > Yapay Zeka.';
      notifyListeners();
      return;
    }
    if (_cache.containsKey(article.id)) return;
    _loadingArticleId = article.id;
    _lastError = null;
    notifyListeners();
    try {
      final result = await _service.summarize(
        article: article,
        apiKey: effectiveApiKey,
        model: _modelId,
      );
      _cache[article.id] = result;
      await _persistCache();
    } on OpenRouterException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = 'Beklenmeyen hata: $e';
    } finally {
      _loadingArticleId = null;
      notifyListeners();
    }
  }

  /// Settings ekranındaki "Bağlantıyı test et" butonu — başarılıysa OK
  /// döner, başarısızsa exception mesajını döner.
  Future<String> testConnection() async {
    if (effectiveApiKey.isEmpty) return 'Önce bir API anahtarı girin.';
    try {
      await _service.testConnection(
        apiKey: effectiveApiKey,
        model: _modelId,
      );
      return 'Bağlantı başarılı.';
    } on OpenRouterException catch (e) {
      return 'Hata: ${e.message}';
    } catch (e) {
      return 'Hata: $e';
    }
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Kullanıcı bir makaleye geri döndüğünde önceki "Özetle" sonucunu silmek
  /// isterse. Detay ekranında "yeniden özetle" akışı için.
  Future<void> invalidate(String articleId) async {
    if (!_cache.containsKey(articleId)) return;
    _cache.remove(articleId);
    notifyListeners();
    await _persistCache();
  }

  /// Sesli brifing gibi serbest bir prompt ile model çağırma. UI'nın özel
  /// servisi (DailyBriefingService) buradan beslenir.
  Future<String> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1000,
  }) async {
    if (!isReady()) {
      throw const OpenRouterException(
        'Yapay zeka kapalı veya yapılandırılmamış. Ayarlar > Yapay Zeka.',
      );
    }
    return _service.generate(
      apiKey: effectiveApiKey,
      model: _modelId,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
    );
  }

  // ─────────── Bias / Yönlülük Analizi ───────────
  /// Bir makaleyi LLM ile bias açısından analiz eder. Cache'lidir; aynı
  /// makale için ikinci çağrı diskten döner. `force=true` yeniden hesaplatır.
  ///
  /// **Not:** Bias detection ≠ fact checking. Burada sadece **dil
  /// özellikleri** (duygu yüklü kelime, tek-perspektif, yorum) puanlanır;
  /// içeriğin doğruluğu test edilmez.
  Future<BiasReport?> analyzeBias(Article article, {bool force = false}) async {
    if (!force && _biasCache.containsKey(article.id)) {
      return _biasCache[article.id];
    }
    if (!isReady()) {
      _lastError =
          'Yapay zeka kapalı veya API anahtarı/model eksik — Ayarlar > Yapay Zeka.';
      notifyListeners();
      return null;
    }
    _loadingBiasId = article.id;
    _lastError = null;
    notifyListeners();
    try {
      final raw = await _service.generate(
        apiKey: effectiveApiKey,
        model: _modelId,
        systemPrompt: _biasSystemPrompt,
        userPrompt: _composeBiasUserPrompt(article),
        maxTokens: 400,
      );
      final report = _parseBiasJson(raw);
      if (report == null) {
        _lastError = 'Yönlülük analizi anlaşılamadı (geçersiz JSON).';
      } else {
        _biasCache[article.id] = report;
        // ignore: unawaited_futures
        _persistBiasCache();
      }
      return report;
    } on OpenRouterException catch (e) {
      _lastError = e.message;
      return null;
    } catch (e) {
      _lastError = 'Beklenmeyen hata: $e';
      return null;
    } finally {
      _loadingBiasId = null;
      notifyListeners();
    }
  }

  static const String _biasSystemPrompt = '''
Sen Türkçe haber metinlerinde dil yönlülüğü tespit eden bir analizcisin.
Görevin SADECE manşetin/metnin dil özelliklerini değerlendirmektir
— olgu doğruluğunu değil.

Sinyaller:
- Duygu yüklü kelimeler (rezalet, skandal, muhteşem)
- Yorum içeren ifadeler (açıkça başarısız oldu)
- Tek perspektif (karşı tarafa söz hakkı vermeyen anlatım)
- Mübalağa, vurgulu ünlem, BÜYÜK HARF
- Yan tutan sıfatlar (sözde, güya)

Çıktı SADECE şu JSON formatında olmalı (başka metin yok):
{
  "score": 0-100 arası tam sayı,
  "label": "Nötr" | "Hafif yönlü" | "Belirgin yönlü" | "Yüksek yönlü",
  "cues": ["max 5 kısa örnek ifade"],
  "summary": "1-2 cümle nesnel açıklama"
}

Skor bantları:
- 0-25: Nötr
- 26-50: Hafif yönlü
- 51-75: Belirgin yönlü
- 76-100: Yüksek yönlü
''';

  String _composeBiasUserPrompt(Article article) {
    final body = article.content.trim().isNotEmpty
        ? (article.content.length > 1500
            ? '${article.content.substring(0, 1500)}…'
            : article.content)
        : article.summary;
    return '''
KAYNAK: ${article.sourceName.isNotEmpty ? article.sourceName : "Bilinmeyen"}
MANŞET: ${article.title}
İÇERİK:
$body

Yukarıdaki haber metninin dil yönlülüğünü değerlendir.
Yalnızca JSON döndür.
''';
  }

  BiasReport? _parseBiasJson(String raw) {
    final cleaned = _stripCodeFence(raw).trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final jsonStr = cleaned.substring(start, end + 1);
    try {
      final decoded = jsonDecode(jsonStr);
      return BiasReport.tryParse(decoded);
    } catch (_) {
      return null;
    }
  }

  String _stripCodeFence(String s) {
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final m = fence.firstMatch(s);
    return m != null ? m.group(1)! : s;
  }

  // ─────────── Haber Asistanı (Q&A) ───────────
  /// Bir makale hakkında kullanıcının özgürce sorduğu soruya cevap.
  /// In-memory cache'lidir (id+question key); kalıcı değildir.
  Future<String?> askQuestion(Article article, String question) async {
    final q = question.trim();
    if (q.isEmpty) return null;
    final cacheKey = '${article.id}::$q';
    final cached = _qaCache[cacheKey];
    if (cached != null) return cached;
    if (!isReady()) {
      _lastError =
          'Yapay zeka kapalı veya API anahtarı/model eksik — Ayarlar > Yapay Zeka.';
      notifyListeners();
      return null;
    }
    _loadingQaId = article.id;
    _lastError = null;
    notifyListeners();
    try {
      final body = article.content.trim().isNotEmpty
          ? (article.content.length > 2500
              ? '${article.content.substring(0, 2500)}…'
              : article.content)
          : article.summary;
      final answer = await _service.generate(
        apiKey: effectiveApiKey,
        model: _modelId,
        systemPrompt: _qaSystemPrompt,
        userPrompt: '''
HABER BAŞLIK: ${article.title}
KAYNAK: ${article.sourceName.isNotEmpty ? article.sourceName : "Bilinmeyen"}
TARİH: ${article.publishedAt.toString().substring(0, 10)}

HABER METNİ:
$body

KULLANICI SORUSU: $q

Soruyu sınıflandır ve kurallara uygun yanıtla.
''',
        maxTokens: 600,
      );
      _qaCache[cacheKey] = answer;
      return answer;
    } on OpenRouterException catch (e) {
      _lastError = e.message;
      return null;
    } catch (e) {
      _lastError = 'Beklenmeyen hata: $e';
      return null;
    } finally {
      _loadingQaId = null;
      notifyListeners();
    }
  }

  static const String _qaSystemPrompt = '''
Sen Türkçe haber okuma asistanısın. Kullanıcı sana bir haber ve soru veriyor.

ÖNCE SORUYU SINIFLANDIR, SONRA YANIT VER:

▸ TİP A — Metinden yanıtlanabilir (sayılar, isimler, olayın detayları, özet):
  Sadece verilen haber metnindeki bilgilere dayan.

▸ TİP B — Bağlam ve önem soruları ("neden önemli?", "arkaplan", "ne anlama geliyor?", 
  "neden oldu?", "kim etkileniyor?", "bu olayın tarihi bağlamı nedir?"):
  Haberi referans al ama genel bilgini de kullan. Haberin konusundan hareketle
  açıklayıcı, zengin bir cevap ver.

▸ TİP C — Haberle tamamen alakasız sorular:
  Kısa yanıt: "Bu soru haberle ilgili değil."

GENEL KURALLAR:
- 150 kelimeyi geçme — kısa ve net.
- Türkçe yanıtla.
- Madde işareti veya başlık koyma — düz metin yaz.
- Tip A: spekülasyon yapma. Tip B: kamuya açık bağlamsal bilgiyi kullanabilirsin.
- Sayıları ve özel isimleri olduğu gibi koru.
''';
}
