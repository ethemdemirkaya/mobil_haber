import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ai/openrouter_client.dart';
import '../data/models/article.dart';
import '../data/repositories/ai_summary_service.dart';

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
  AiSettingsProvider({AiSummaryService? service})
      : _service = service ?? AiSummaryService() {
    _load();
  }

  final AiSummaryService _service;

  bool _initialized = false;
  bool _enabled = false;
  String _apiKey = '';
  String _modelId = defaultModelId;

  /// articleId → özet metni
  final Map<String, String> _cache = <String, String>{};

  /// Aktif çağrı durumu — UI loading indicator için. Aynı anda 1 çağrı.
  String? _loadingArticleId;
  String? _lastError;

  static const String _prefsEnabled = 'pref_ai_enabled';
  static const String _prefsKey = 'pref_ai_api_key';
  static const String _prefsModel = 'pref_ai_model';
  static const String _prefsCache = 'pref_ai_cache';

  /// Default — Claude Haiku, en hızlı ve en ucuz Anthropic modeli.
  static const String defaultModelId = 'anthropic/claude-3.5-haiku';

  /// Kullanıcıya sunulan hazır model listesi. ID'ler OpenRouter'ın resmi
  /// model id'leri ile eşleşmelidir. Listede olmayan modelleri kullanmak
  /// için "Diğer" seçilip elle id girilebilir.
  static const List<AiModelPreset> presets = [
    AiModelPreset(
      id: 'anthropic/claude-3.5-haiku',
      label: 'Claude 3.5 Haiku',
      description: 'Anthropic — hızlı, ucuz, makale özetleri için ideal.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'anthropic/claude-3.5-sonnet',
      label: 'Claude 3.5 Sonnet',
      description: 'Anthropic — daha tutarlı, biraz daha pahalı.',
      tier: AiModelTier.balanced,
    ),
    AiModelPreset(
      id: 'openai/gpt-4o-mini',
      label: 'GPT-4o mini',
      description: 'OpenAI — Haiku\'ya rakip, güçlü Türkçe.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'openai/gpt-4o',
      label: 'GPT-4o',
      description: 'OpenAI — yüksek kalite, daha pahalı.',
      tier: AiModelTier.premium,
    ),
    AiModelPreset(
      id: 'google/gemini-flash-1.5',
      label: 'Gemini 1.5 Flash',
      description: 'Google — çok hızlı, geniş context.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'meta-llama/llama-3.1-70b-instruct',
      label: 'Llama 3.1 70B',
      description: 'Meta — açık ağırlıklı, ucuz.',
      tier: AiModelTier.balanced,
    ),
    AiModelPreset(
      id: 'deepseek/deepseek-chat',
      label: 'DeepSeek Chat',
      description: 'DeepSeek — düşük maliyet, iyi performans.',
      tier: AiModelTier.fast,
    ),
    AiModelPreset(
      id: 'google/gemini-2.0-flash-exp:free',
      label: 'Gemini 2.0 Flash (free)',
      description: 'Google — ücretsiz katman, sıkı rate limit.',
      tier: AiModelTier.free,
    ),
  ];

  // ─────────── Getters ───────────
  bool get initialized => _initialized;
  bool get enabled => _enabled;
  String get apiKey => _apiKey;
  String get modelId => _modelId;
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Aktif modelin görünen adı — hazır listedeyse label, değilse id.
  String get currentModelLabel {
    for (final p in presets) {
      if (p.id == _modelId) return p.label;
    }
    return _modelId.isEmpty ? 'Seçilmedi' : _modelId;
  }

  String? get loadingArticleId => _loadingArticleId;
  String? get lastError => _lastError;

  /// Belirli bir makale için cache'lenmiş özet (yoksa null).
  String? cachedSummary(String articleId) => _cache[articleId];

  /// Kullanıcıya bu makale için "Özetle" butonu gösterilmeli mi?
  bool isReady() => _enabled && _apiKey.isNotEmpty && _modelId.isNotEmpty;

  // ─────────── Persistence ───────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsEnabled) ?? false;
    _apiKey = prefs.getString(_prefsKey) ?? '';
    _modelId = prefs.getString(_prefsModel) ?? defaultModelId;
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
        apiKey: _apiKey,
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
    try {
      await _service.testConnection(apiKey: _apiKey, model: _modelId);
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
}
