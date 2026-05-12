import 'dart:convert';

import 'package:http/http.dart' as http;

/// Bir OpenRouter modelinin runtime listesinde gözüken hâli.
/// `/api/v1/models` endpoint'inden parse edilen alt küme.
class OpenRouterModel {
  const OpenRouterModel({
    required this.id,
    required this.name,
    required this.contextLength,
    required this.promptPrice,
    required this.completionPrice,
    required this.modality,
  });

  /// `provider/model-name[:tag]` formatı; OpenRouter API'ye birebir gider.
  final String id;
  final String name;
  final int contextLength;

  /// USD per token (string olarak gelir; "0" → tamamen ücretsiz).
  final String promptPrice;
  final String completionPrice;

  /// `text->text`, `text+image->text` vs.
  final String modality;

  /// `:free` suffix'li veya prompt fiyatı 0 olan modeller. Bunlar
  /// OpenRouter'ın "free tier"ında çalışır (rate-limit ile).
  bool get isFree =>
      id.endsWith(':free') ||
      promptPrice == '0' ||
      promptPrice == '0.0' ||
      promptPrice == '0.00';

  /// Sağlayıcı (id'nin `/`'den önceki kısmı). UI rozet için.
  String get provider {
    final i = id.indexOf('/');
    if (i < 0) return id;
    return id.substring(0, i);
  }

  /// 1M token için USD fiyat (insan-okur). Free için boş.
  String? get promptPricePerMillion {
    if (isFree) return null;
    final p = double.tryParse(promptPrice);
    if (p == null || p == 0) return null;
    final perM = p * 1000000;
    return '\$${perM.toStringAsFixed(2)}/1M';
  }

  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'];
    final arch = json['architecture'];
    return OpenRouterModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contextLength: (json['context_length'] as num?)?.toInt() ?? 0,
      promptPrice: pricing is Map ? (pricing['prompt']?.toString() ?? '0') : '0',
      completionPrice:
          pricing is Map ? (pricing['completion']?.toString() ?? '0') : '0',
      modality: arch is Map ? (arch['modality']?.toString() ?? 'text->text') : 'text->text',
    );
  }
}

/// OpenRouter'dan canlı model listesini çeken repository.
///
/// `/api/v1/models` public endpoint — auth gerekmez. Liste 100+ modeli
/// içerir; bizim için kritik subset:
///   - Filter: `:free` suffix veya pricing.prompt == 0
///   - Sort: provider + name
///
/// In-memory cache + 6 saatlik TTL ile aşırı API çağrısı yapmıyoruz.
class OpenRouterModelsRepository {
  OpenRouterModelsRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint = 'https://openrouter.ai/api/v1/models';
  static const Duration _cacheTtl = Duration(hours: 6);
  static const Duration _timeout = Duration(seconds: 12);

  List<OpenRouterModel>? _cached;
  DateTime? _cachedAt;

  bool get hasCache => _cached != null;

  /// Tüm modelleri (cache valid ise) döner. Force refresh için
  /// [forceRefresh] true.
  Future<List<OpenRouterModel>> fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }
    final response = await _client
        .get(
          Uri.parse(_endpoint),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'mobil_haber/1.0',
          },
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('OpenRouter modeller HTTP ${response.statusCode}');
    }
    final body = utf8.decode(response.bodyBytes);
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw Exception('Beklenmeyen yanıt formatı.');
    }
    final list = (decoded['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(OpenRouterModel.fromJson)
        .where((m) => m.id.isNotEmpty)
        .toList(growable: false);
    list.sort((a, b) {
      final p = a.provider.compareTo(b.provider);
      if (p != 0) return p;
      return a.name.compareTo(b.name);
    });
    _cached = list;
    _cachedAt = DateTime.now();
    return list;
  }

  /// Yalnızca ücretsiz olarak listelenenleri döner.
  Future<List<OpenRouterModel>> fetchFree({bool forceRefresh = false}) async {
    final all = await fetchAll(forceRefresh: forceRefresh);
    return all.where((m) => m.isFree).toList(growable: false);
  }

  void close() => _client.close();
}
