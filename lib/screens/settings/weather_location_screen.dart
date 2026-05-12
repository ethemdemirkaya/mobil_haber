import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/market_widget_service.dart';
import '../../providers/preferences_provider.dart';

/// Brifing ekranındaki hava durumu için şehir seçimi.
///
/// Open-Meteo geocoding API ile (auth yok) anlık arama → kullanıcı
/// listeden seçer → lat/lon ile birlikte PreferencesProvider'a kaydedilir.
/// Brifing sonraki açılışta yeni konuma göre hava çeker.
class WeatherLocationScreen extends StatefulWidget {
  const WeatherLocationScreen({super.key});

  @override
  State<WeatherLocationScreen> createState() => _WeatherLocationScreenState();
}

class _WeatherLocationScreenState extends State<WeatherLocationScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final MarketWidgetService _service = MarketWidgetService();

  Timer? _debounce;
  List<GeocodedCity> _results = const [];
  bool _searching = false;

  /// Hızlı seçim için sık kullanılan TR şehirleri.
  static const List<_QuickCity> _quick = [
    _QuickCity('İstanbul', 41.0082, 28.9784),
    _QuickCity('Ankara', 39.9208, 32.8541),
    _QuickCity('İzmir', 38.4192, 27.1287),
    _QuickCity('Bursa', 40.1828, 29.0665),
    _QuickCity('Antalya', 36.8969, 30.7133),
    _QuickCity('Adana', 37.0000, 35.3213),
    _QuickCity('Konya', 37.8716, 32.4847),
    _QuickCity('Gaziantep', 37.0662, 37.3833),
    _QuickCity('Trabzon', 41.0027, 39.7178),
    _QuickCity('Eskişehir', 39.7767, 30.5206),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = await _service.searchCities(q);
    if (!mounted) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  Future<void> _select(String city, double lat, double lon) async {
    HapticFeedback.selectionClick();
    await context.read<PreferencesProvider>().setWeatherLocation(
          cityName: city,
          lat: lat,
          lon: lon,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Brifing artık $city için hava bilgisi alacak.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prefs = context.watch<PreferencesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brifing Bölgesi'),
      ),
      body: Column(
        children: [
          // Aktif şehir bilgisi.
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.14),
                  cs.tertiary.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.place, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prefs.weatherCityName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${prefs.weatherLat.toStringAsFixed(2)}, '
                        '${prefs.weatherLon.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Arama kutusu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _input,
              focusNode: _focus,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Şehir ara… (örn. Trabzon, İzmir, Berlin)',
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                suffixIcon: _input.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _input.clear();
                          setState(() => _results = const []);
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onChanged,
            ),
          ),

          if (_results.isEmpty && _input.text.trim().length < 2) ...[
            // Hızlı seçim listesi
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'HIZLI SEÇİM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _quick.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, i) {
                  final c = _quick[i];
                  final selected = c.name == prefs.weatherCityName;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: selected
                          ? cs.primary
                          : cs.primary.withValues(alpha: 0.14),
                      child: Icon(
                        selected ? Icons.check : Icons.location_city,
                        color: selected ? cs.onPrimary : cs.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    onTap: () => _select(c.name, c.lat, c.lon),
                  );
                },
              ),
            ),
          ] else ...[
            // Arama sonuçları
            Expanded(
              child: _results.isEmpty && !_searching
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Sonuç bulunamadı.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color:
                            cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                      itemBuilder: (context, i) {
                        final c = _results[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                cs.primary.withValues(alpha: 0.14),
                            child: Icon(Icons.place,
                                color: cs.primary, size: 18),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            [c.admin, c.country]
                                .where((s) => s.isNotEmpty)
                                .join(', '),
                          ),
                          trailing: Text(
                            '${c.lat.toStringAsFixed(1)}°',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          onTap: () => _select(c.name, c.lat, c.lon),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickCity {
  const _QuickCity(this.name, this.lat, this.lon);
  final String name;
  final double lat;
  final double lon;
}
