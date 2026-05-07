import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ai/openrouter_client.dart';
import '../data/models/article.dart';
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

/// Sesli brifing okumak için hangi motorun kullanılacağı.
enum TtsEngineKind {
  /// flutter_tts: cihazın native TTS'i. Hızlı, ücretsiz, çevrimdışı.
  /// Türkçe ses kalitesi cihaza göre değişir.
  system,

  /// OpenAI `audio/speech`: yüksek kaliteli MP3, parametrik ses seçimi.
  /// Kullanıcı kendi OpenAI API anahtarını girer (OpenRouter'dan ayrı).
  /// Maliyet: \$15/1M karakter (~brifing başına \$0.015).
  openai,
}

extension TtsEngineKindLabel on TtsEngineKind {
  String get label => switch (this) {
        TtsEngineKind.system => 'Sistem TTS (varsayılan)',
        TtsEngineKind.openai => 'OpenAI TTS (yüksek kalite)',
      };

  String get description => switch (this) {
        TtsEngineKind.system => 'Cihazın yerleşik konuşma motoru — '
            'ücretsiz ve çevrimdışı, kalite cihaza bağlı.',
        TtsEngineKind.openai => 'OpenAI sunucularında üretilen MP3, '
            'doğal ses. OpenAI API anahtarı + ücret gerekir.',
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
  bool _enabled = false;
  String _apiKey = '';
  String _modelId = defaultModelId;

  // ─── TTS (sesli okuma) ───
  TtsEngineKind _ttsEngine = TtsEngineKind.system;
  String _openaiTtsKey = '';
  String _openaiTtsVoice = 'nova';
  String _openaiTtsModel = 'tts-1';

  // ─── First-run banner ───
  /// Build-time anahtar ile gelen yeni kullanıcı için "AI hazır" bildirimi
  /// bir kez gösterildi mi?
  bool _firstRunNoticeShown = false;

  /// articleId → özet metni
  final Map<String, String> _cache = <String, String>{};

  /// Aktif çağrı durumu — UI loading indicator için. Aynı anda 1 çağrı.
  String? _loadingArticleId;
  String? _lastError;

  static const String _prefsEnabled = 'pref_ai_enabled';
  static const String _prefsKey = 'pref_ai_api_key';
  static const String _prefsModel = 'pref_ai_model';
  static const String _prefsCache = 'pref_ai_cache';
  static const String _prefsTtsEngine = 'pref_ai_tts_engine';
  static const String _prefsOpenaiTtsKey = 'pref_ai_openai_tts_key';
  static const String _prefsOpenaiTtsVoice = 'pref_ai_openai_tts_voice';
  static const String _prefsOpenaiTtsModel = 'pref_ai_openai_tts_model';
  static const String _prefsFirstRunNotice = 'pref_ai_first_run_notice';

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

  /// API çağrılarında kullanılacak gerçek anahtar — kullanıcı girdiyse
  /// onu (kendi rate-limit/spend cap kontrolü), girmediyse build-time
  /// embed'i. İkisi de yoksa boş string (`isReady` false döner).
  String get effectiveApiKey =>
      _apiKey.isNotEmpty ? _apiKey : OpenRouterClient.defaultApiKey;

  /// Etkin anahtarın kaynağı — UI'da "kendi anahtarınız" / "uygulama
  /// içinde gömülü" rozetini ayırt etmek için.
  AiKeySource get keySource {
    if (_apiKey.isNotEmpty) return AiKeySource.userProvided;
    if (OpenRouterClient.hasBuiltInKey) return AiKeySource.builtIn;
    return AiKeySource.none;
  }

  bool get hasAnyKey => effectiveApiKey.isNotEmpty;

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

  /// Seçili TTS motoru kullanılabilir durumda mı? OpenAI seçildiyse
  /// anahtar girilmiş olmalı.
  bool get isTtsEngineUsable {
    if (_ttsEngine == TtsEngineKind.system) return true;
    return _openaiTtsKey.isNotEmpty;
  }

  // ─── First-run notice ───
  /// Sadece şu an gösterilmeli mi? — built-in key VAR + henüz görmemiş.
  bool get shouldShowFirstRunNotice =>
      !_firstRunNoticeShown && keySource == AiKeySource.builtIn;

  bool get firstRunNoticeShown => _firstRunNoticeShown;

  /// Belirli bir makale için cache'lenmiş özet (yoksa null).
  String? cachedSummary(String articleId) => _cache[articleId];

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
    _initialized = true;
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
}
