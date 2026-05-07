import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Hava + döviz "mini widget" verisi sağlayıcısı.
///
/// İki ücretsiz, anahtar gerektirmeyen API:
///
/// 1. **Open-Meteo** (https://open-meteo.com) — hava durumu.
///    Auth yok, rate limit 10K istek/gün anonim. Konum: lat/lon.
///    Cevap: current temperature_2m, weather_code (WMO), wind_speed_10m.
///
/// 2. **Frankfurter** (https://api.frankfurter.dev) — döviz kurları.
///    Auth yok, ECB referans kuru, hızlı. Cevap: rates map.
///    USD/TRY, EUR/TRY, GBP/TRY çekiyoruz.
///
/// Brifing ekranı en üstte gösterir; AI prompt'una da besleyebiliriz
/// ("Bugün İstanbul'da hava 18°C, parçalı bulutlu; dolar 38.42, euro 41.10").
class MarketWidgetService {
  MarketWidgetService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 6);

  /// İstanbul varsayılan koordinatı.
  static const double _defaultLat = 41.0082;
  static const double _defaultLon = 28.9784;
  static const String _defaultCity = 'İstanbul';

  Future<MarketSnapshot> fetch({
    double lat = _defaultLat,
    double lon = _defaultLon,
    String city = _defaultCity,
  }) async {
    // Paralel: weather + currency
    final results = await Future.wait([
      _fetchWeather(lat, lon).catchError((Object _) => const _NullWeather()),
      _fetchCurrency().catchError((Object _) => const <String, double>{}),
    ]);
    final weather = results[0] as _MaybeWeather;
    final currency = results[1] as Map<String, double>;
    return MarketSnapshot(
      city: city,
      weather: weather is WeatherSnapshot ? weather : null,
      tryRates: currency,
      fetchedAt: DateTime.now(),
    );
  }

  Future<_MaybeWeather> _fetchWeather(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,weather_code,wind_speed_10m'
      '&timezone=Europe/Istanbul',
    );
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Open-Meteo HTTP ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final current = body is Map ? body['current'] : null;
    if (current is! Map) throw Exception('Open-Meteo cevap formatı');
    return WeatherSnapshot(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      windKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<Map<String, double>> _fetchCurrency() async {
    // EUR base'den USD/GBP/TRY/JPY sorgusu — ECB feed'ine yakın.
    // Sonra TRY'yi base alıp tersine çeviriyoruz.
    final uri = Uri.parse(
      'https://api.frankfurter.dev/v1/latest?base=USD&symbols=TRY,EUR,GBP',
    );
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Frankfurter HTTP ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map || body['rates'] is! Map) {
      throw Exception('Frankfurter cevap formatı');
    }
    final rates = body['rates'] as Map;
    final usdToTry = (rates['TRY'] as num?)?.toDouble();
    final eurToTry = (() {
      final usdToEur = (rates['EUR'] as num?)?.toDouble();
      if (usdToEur == null || usdToEur == 0 || usdToTry == null) return null;
      return usdToTry / usdToEur;
    })();
    final gbpToTry = (() {
      final usdToGbp = (rates['GBP'] as num?)?.toDouble();
      if (usdToGbp == null || usdToGbp == 0 || usdToTry == null) return null;
      return usdToTry / usdToGbp;
    })();

    final out = <String, double>{};
    if (usdToTry != null) out['USD'] = usdToTry;
    if (eurToTry != null) out['EUR'] = eurToTry;
    if (gbpToTry != null) out['GBP'] = gbpToTry;
    return out;
  }

  void close() => _client.close();
}

abstract class _MaybeWeather {
  const _MaybeWeather();
}

class _NullWeather extends _MaybeWeather {
  const _NullWeather();
}

class WeatherSnapshot extends _MaybeWeather {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.weatherCode,
    required this.windKmh,
  });

  final double temperatureC;
  final int weatherCode;
  final double windKmh;

  /// WMO weather code → kısa Türkçe açıklama. Tam liste:
  /// https://open-meteo.com/en/docs (weather_code).
  String get description {
    final c = weatherCode;
    if (c == 0) return 'Açık';
    if (c <= 3) return 'Parçalı bulutlu';
    if (c == 45 || c == 48) return 'Sisli';
    if (c >= 51 && c <= 57) return 'Çisenti';
    if (c >= 61 && c <= 67) return 'Yağmurlu';
    if (c >= 71 && c <= 77) return 'Karlı';
    if (c >= 80 && c <= 82) return 'Sağanak';
    if (c == 95) return 'Gök gürültülü fırtına';
    if (c >= 96 && c <= 99) return 'Dolu fırtınası';
    return 'Bulutlu';
  }

  /// Bu açıklamaya uygun emoji yerine Material icon adı (UI ikonlu chip
  /// için). Basit eşleme.
  String get emoji {
    final c = weatherCode;
    if (c == 0) return '☀️';
    if (c <= 3) return '⛅';
    if (c == 45 || c == 48) return '🌫️';
    if (c >= 51 && c <= 67) return '🌧️';
    if (c >= 71 && c <= 77) return '❄️';
    if (c >= 80 && c <= 82) return '🌦️';
    if (c >= 95) return '⛈️';
    return '☁️';
  }
}

class MarketSnapshot {
  const MarketSnapshot({
    required this.city,
    required this.weather,
    required this.tryRates,
    required this.fetchedAt,
  });

  final String city;
  final WeatherSnapshot? weather;
  final Map<String, double> tryRates;
  final DateTime fetchedAt;

  bool get hasAny => weather != null || tryRates.isNotEmpty;

  /// AI brifing prompt'una eklenecek doğal dil cümle.
  /// Hem hava hem döviz varsa ikisini birleştirir.
  String? toSpokenIntro() {
    final parts = <String>[];
    if (weather != null) {
      parts.add(
        '$city\'da hava ${weather!.temperatureC.toStringAsFixed(0)} '
        'dereceyle ${weather!.description.toLowerCase()}',
      );
    }
    if (tryRates.isNotEmpty) {
      final usd = tryRates['USD'];
      final eur = tryRates['EUR'];
      final pieces = <String>[];
      if (usd != null) pieces.add('dolar ${usd.toStringAsFixed(2)} lira');
      if (eur != null) pieces.add('euro ${eur.toStringAsFixed(2)} lira');
      if (pieces.isNotEmpty) parts.add(pieces.join(', '));
    }
    if (parts.isEmpty) return null;
    return '${parts.join('; ')}.';
  }
}
