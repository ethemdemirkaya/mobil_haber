import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ai/openrouter_client.dart';
import '../data/local/ai_cache_store.dart';
import '../data/models/article.dart';
import '../core/utils/turkish_text.dart';
import '../data/models/bias_report.dart';
import '../data/models/qa_answer.dart';
import '../data/repositories/ai_summary_service.dart';
import '../data/repositories/article_text_extractor.dart';
import '../data/repositories/language_signal_analyzer.dart';
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
///   - özet ve bias cache'leri SQLite `ai_cache` tablosunda (AiCacheStore —
///     tür başına 300 kayıt, 30 gün)
///
/// **Güvenlik notu:** API anahtarı cihazın SharedPreferences'ında
/// düz metin saklanır. Production sürümde Keychain/Keystore (örn.
/// `flutter_secure_storage`) kullanılmalı. Demo aşamada bu yeterli.
class AiSettingsProvider extends ChangeNotifier {
  AiSettingsProvider({
    AiSummaryService? service,
    OpenRouterModelsRepository? modelsRepo,
    AiCacheStore aiCache = const AiCacheStore(),
    ArticleTextExtractor? textExtractor,
  })  : _service = service ?? AiSummaryService(),
        _modelsRepo = modelsRepo ?? OpenRouterModelsRepository(),
        _aiCache = aiCache,
        _extractor = textExtractor ?? ArticleTextExtractor() {
    _load();
  }

  final AiSummaryService _service;
  final OpenRouterModelsRepository _modelsRepo;
  final AiCacheStore _aiCache;
  final ArticleTextExtractor _extractor;
  static const LanguageSignalAnalyzer _signals = LanguageSignalAnalyzer();

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
  final Map<String, QaAnswer> _qaCache = <String, QaAnswer>{};

  /// Aktif çağrı durumu — UI loading indicator için. Aynı anda 1 çağrı.
  String? _loadingArticleId;
  String? _loadingBiasId;

  /// Son yönlülük analizi başarısız olan makale — kart hatayı gösterir.
  String? _biasErrorId;
  String? _loadingQaId;
  String? _lastError;

  static const String _prefsEnabled = 'pref_ai_enabled';
  static const String _prefsKey = 'pref_ai_api_key';
  static const String _prefsKeyMode = 'pref_ai_key_mode';
  static const String _prefsModel = 'pref_ai_model';
  static const String _prefsCache = 'pref_ai_cache';
  static const String _prefsBiasCache = 'pref_ai_bias_cache';
  static const String _prefsFirstRunNotice = 'pref_ai_first_run_notice';

  /// Default — NVIDIA Nemotron 3 Super, OpenRouter'da :free katmanda
  /// rate-limit ile ücretsiz (Ekim 2026'da doğrulandı). Ücretsiz modeller
  /// sık değiştiği için kaldırılanlar [_retiredModelIds] ile otomatik
  /// taşınır.
  static const String defaultModelId = 'nvidia/nemotron-3-super-120b-a12b:free';

  /// OpenRouter'ın ücretsiz katmandan kaldırdığı (404 dönen) modeller.
  /// Kullanıcı bunlardan birini kaydetmişse açılışta varsayılana taşınır;
  /// aksi hâlde tüm AI özellikleri sessizce çalışmaz.
  static const Set<String> _retiredModelIds = {
    'openai/gpt-oss-20b:free',
    'google/gemini-2.0-flash-exp:free',
  };

  /// Kullanıcıya sunulan hazır model listesi. ID'ler OpenRouter'ın resmi
  /// model id'leri ile eşleşmelidir. Listede olmayan modelleri kullanmak
  /// için "Diğer" seçilip elle id girilebilir.
  ///
  /// Sıralama: önce ücretsiz seçenekler (yeni kullanıcı için sıfır maliyet),
  /// sonra ucuz hızlılar, sonra premium.
  static const List<AiModelPreset> presets = [
    AiModelPreset(
      id: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super (free)',
      description:
          'NVIDIA 120B — varsayılan, ücretsiz katmanda kullanım.',
      tier: AiModelTier.free,
    ),
    AiModelPreset(
      id: 'google/gemma-4-31b-it:free',
      label: 'Gemma 4 31B (free)',
      description: 'Google — ücretsiz, çok dilli (yoğun saatlerde 429 '
          'verebilir).',
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

  // ─── First-run notice ───
  /// Sadece şu an gösterilmeli mi? — built-in key VAR + henüz görmemiş.
  bool get shouldShowFirstRunNotice =>
      !_firstRunNoticeShown && keySource == AiKeySource.builtIn;

  bool get firstRunNoticeShown => _firstRunNoticeShown;

  /// Belirli bir makale için cache'lenmiş özet (yoksa null).
  String? cachedSummary(String articleId) => _cache[articleId];

  /// Cache'lenmiş bias raporu — yoksa null. Yeniden çağırma ücret
  /// üretmesin diye kalıcı cache'liyoruz.
  BiasReport? cachedBias(String articleId) =>
      _biasCache[_biasKey(articleId)];

  /// Bias sonucu modele bağlıdır; model değişince eski skor gösterilmez.
  String _biasKey(String articleId) => '$articleId::$_modelId';

  /// AI'a verilecek haber metni: RSS içeriği yeterince uzunsa o, değilse
  /// orijinal sayfadan çıkarılan gövde metni; ikisi de yoksa elimizdeki
  /// en uzun metin.
  Future<String> _groundingText(Article article) async {
    final content = article.content.trim();
    final summary = article.summary.trim();
    final own = content.length >= summary.length ? content : summary;
    if (own.length >= AiSummaryService.minSourceChars ||
        !article.hasOriginalUrl) {
      return own;
    }
    final extracted = await _extractor.extract(article.sourceUrl);
    return (extracted != null && extracted.length > own.length)
        ? extracted
        : own;
  }

  /// In-memory Q&A cache. Aynı oturumda tekrar açılırsa hızlıca dönsün
  /// diye. Kalıcı değil — token israfını önlemek için disk'e yazmıyoruz.
  QaAnswer? cachedAnswer(String articleId, String question) =>
      _qaCache['$articleId::${question.trim()}'];

  /// Aktif bias çağrısının makale id'si — UI loading state.
  String? get loadingBiasId => _loadingBiasId;

  /// Bu makalenin son yönlülük analizi başarısız olduysa hata mesajı.
  String? biasErrorFor(String articleId) =>
      _biasErrorId == articleId ? _lastError : null;

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
    if (_retiredModelIds.contains(_modelId)) {
      _modelId = defaultModelId;
      await prefs.setString(_prefsModel, _modelId);
    }

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

    _firstRunNoticeShown = prefs.getBool(_prefsFirstRunNotice) ?? false;

    await _loadAiCaches(prefs);
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    notifyListeners();
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

  /// Özet ve bias cache'lerini SQLite'tan yükler. Eski sürümün
  /// SharedPreferences'taki JSON blob'larını bir kez taşıyıp siler.
  Future<void> _loadAiCaches(SharedPreferences prefs) async {
    try {
      final legacySummaries = _decodeLegacyMap(prefs.getString(_prefsCache));
      if (legacySummaries.isNotEmpty) {
        await _aiCache.putAll(AiCacheStore.kindSummary, {
          for (final e in legacySummaries.entries)
            if (e.value is String) e.key: e.value as String,
        });
      }
      final legacyBias = _decodeLegacyMap(prefs.getString(_prefsBiasCache));
      if (legacyBias.isNotEmpty) {
        await _aiCache.putAll(AiCacheStore.kindBias, {
          for (final e in legacyBias.entries) e.key: jsonEncode(e.value),
        });
      }
      await prefs.remove(_prefsCache);
      await prefs.remove(_prefsBiasCache);

      _cache
        ..clear()
        ..addAll(await _aiCache.load(AiCacheStore.kindSummary));
      _biasCache.clear();
      (await _aiCache.load(AiCacheStore.kindBias)).forEach((k, v) {
        try {
          final report = BiasReport.tryParse(jsonDecode(v));
          if (report != null) _biasCache[k] = report;
        } on FormatException {
          // Bozuk kayıt: yok say.
        }
      });
    } catch (e) {
      debugPrint('[Pusula][AiCache] yükleme hatası: $e');
    }
  }

  static Map<String, Object?> _decodeLegacyMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final e in decoded.entries)
            if (e.key is String) e.key as String: e.value,
        };
      }
    } catch (_) {
      // Bozuk cache: yok say.
    }
    return const {};
  }

  Future<void> _persistSummary(String articleId, String summary) async {
    try {
      await _aiCache.put(AiCacheStore.kindSummary, articleId, summary);
    } catch (e) {
      debugPrint('[Pusula][AiCache] yazma hatası: $e');
    }
  }

  Future<void> _persistBias(String articleId, BiasReport report) async {
    try {
      await _aiCache.put(
          AiCacheStore.kindBias, articleId, jsonEncode(report.toJson()));
    } catch (e) {
      debugPrint('[Pusula][AiCache] yazma hatası: $e');
    }
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
    await _aiCache.clear(AiCacheStore.kindSummary);
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
      final text = await _groundingText(article);
      if (text.length < AiSummaryService.minSourceChars) {
        // Tek cümlelik açıklamayı "özetlemek" tekrar ya da uydurma üretir.
        _lastError = 'Bu haberin özetlenecek kadar metni yok — kaynak '
            'yalnızca kısa bir açıklama yayınlamış. Tam metni kaynağın '
            'sitesinden okuyabilirsin.';
        return;
      }
      final result = await _service.summarize(
        article: article,
        sourceText: text,
        apiKey: effectiveApiKey,
        model: _modelId,
      );
      _cache[article.id] = result;
      await _persistSummary(article.id, result);
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
    await _aiCache.remove(AiCacheStore.kindSummary, articleId);
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
    final key = _biasKey(article.id);
    if (!force && _biasCache.containsKey(key)) {
      return _biasCache[key];
    }
    if (!isReady()) {
      _lastError =
          'Yapay zeka kapalı veya API anahtarı/model eksik — Ayarlar > Yapay Zeka.';
      notifyListeners();
      return null;
    }
    _loadingBiasId = article.id;
    _biasErrorId = null;
    _lastError = null;
    notifyListeners();
    try {
      final body = await _groundingText(article);
      final raw = await _service.generate(
        apiKey: effectiveApiKey,
        model: _modelId,
        systemPrompt: _biasSystemPrompt,
        userPrompt: _composeBiasUserPrompt(article, body),
        maxTokens: 400,
        // Aynı haber için tekrar üretilebilir sonuç.
        temperature: 0,
      );
      final llm = _parseBiasJson(raw);
      if (llm == null) {
        _lastError = 'Yönlülük analizi anlaşılamadı (geçersiz JSON).';
        return null;
      }
      final report = _crossCheckBias(llm, article, body);
      _biasCache[key] = report;
      // ignore: unawaited_futures
      _persistBias(key, report);
      return report;
    } on OpenRouterException catch (e) {
      _lastError = e.message;
      return null;
    } catch (e) {
      _lastError = 'Beklenmeyen hata: $e';
      return null;
    } finally {
      if (_lastError != null) _biasErrorId = article.id;
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
  "cues": ["metinden BİREBİR kopyalanmış en fazla 5 kısa ifade"],
  "summary": "1-2 cümle nesnel açıklama"
}

Kurallar:
- "cues" içindeki her ifade metinde harfi harfine geçmelidir; metinde
  olmayan ifade yazma, ifadeyi değiştirme veya özetleme.
- Yönlü bir ifade bulamıyorsan "cues" boş liste olsun ve skor 0-25 olsun.

Skor bantları:
- 0-25: Nötr
- 26-50: Hafif yönlü
- 51-75: Belirgin yönlü
- 76-100: Yüksek yönlü
''';

  /// LLM sonucunu metne ve kural tabanlı ölçüme karşı doğrular:
  /// metinde geçmeyen "alıntılar" atılır, iki ölçümün uyumundan güven
  /// düzeyi hesaplanır.
  BiasReport _crossCheckBias(BiasReport llm, Article article, String body) {
    final haystack = foldTr('${article.title} $body');
    final verified = llm.cues
        .where((c) => c.trim().isNotEmpty && haystack.contains(foldTr(c)))
        .toList(growable: false);
    final signals = _signals.analyze(title: article.title, body: body);
    return BiasReport(
      score: llm.score,
      label: llm.label,
      cues: verified,
      summary: llm.summary,
      lexicalScore: signals.score,
      lexicalCues: signals.cues
          .map((c) => c.text)
          .where((t) => t != '!' && t != '?' && t != '…')
          .toList(growable: false),
      confidence: BiasReport.assessConfidence(
        llmScore: llm.score,
        lexicalScore: signals.score,
        claimedCues: llm.cues.length,
        verifiedCues: verified.length,
      ),
    );
  }

  String _composeBiasUserPrompt(Article article, String fullBody) {
    final body = fullBody.length > 1500
        ? '${fullBody.substring(0, 1500)}…'
        : fullBody;
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
  Future<QaAnswer?> askQuestion(Article article, String question) async {
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
      final text = await _groundingText(article);
      final body =
          text.length > 2500 ? '${text.substring(0, 2500)}…' : text;
      final raw = await _service.generate(
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
        temperature: 0.2,
      );
      final answer = QaAnswer.parse(raw);
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

ÖNCE SORUYU SINIFLANDIR, SONRA YANIT VER. Yanıtın İLK SATIRI şu
etiketlerden biri olmalı, ardından cevap gelir:

[HABERDE] — Cevap tamamen verilen haber metnindeki bilgiye dayanıyor.
  Sayılar, isimler, olayın ayrıntıları. Metinde yoksa bu etiketi KULLANMA.

[GENEL BİLGİ] — Bağlam/arka plan soruları ("neden önemli?", "arka planı
  ne?") ya da cevabı metinde olmayan sorular. Genel bilgini kullanabilirsin
  ama:
  - Haberde geçmeyen güncel olayları, tarihleri veya sayıları uydurma.
  - Emin değilsen "kesin bilgim yok" de.
  - Bilgin güncel olmayabilir; bunu gerekirse belirt.

[ALAKASIZ] — Soru haberle ilgili değil. Tek cümle: "Bu soru haberle
  ilgili değil."

GENEL KURALLAR:
- 150 kelimeyi geçme — kısa ve net.
- Türkçe yanıtla.
- Madde işareti veya başlık koyma — düz metin yaz.
- Sayıları ve özel isimleri olduğu gibi koru.
''';

}
