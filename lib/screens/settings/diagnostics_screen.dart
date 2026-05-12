import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/reading_history_provider.dart';
import '../../providers/search_provider.dart';

class _SourceHealth {
  const _SourceHealth({
    required this.id,
    required this.name,
    required this.ok,
    required this.message,
    required this.latencyMs,
  });

  final String id;
  final String name;
  final bool ok;
  final String message;
  final int latencyMs;

  factory _SourceHealth.fromJson(Map<String, dynamic> j) {
    return _SourceHealth(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      ok: j['ok'] == true,
      message: (j['message'] ?? '').toString(),
      latencyMs: (j['latencyMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _loading = false;
  String? _error;
  List<_SourceHealth> _health = const [];
  Map<String, dynamic>? _healthBaseInfo;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient();
      final base = await client.get('/health');
      if (base is Map<String, dynamic>) {
        _healthBaseInfo = base;
      }
      final raw = await client.get(
        '/external/health',
        timeout: const Duration(seconds: 60),
      );
      if (raw is List) {
        _health = raw
            .whereType<Map<String, dynamic>>()
            .map(_SourceHealth.fromJson)
            .toList(growable: false);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final newsProv = context.watch<NewsProvider>();
    final bookmarks = context.watch<BookmarkProvider>();
    final history = context.watch<ReadingHistoryProvider>();
    final search = context.watch<SearchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanılama'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadHealth,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section(
            title: 'Uygulama',
            child: Column(
              children: [
                _Row(label: 'Sürüm', value: AppConstants.appVersion),
                _Row(label: 'Build', value: AppConstants.appBuild),
                _Row(
                  label: 'API Base URL',
                  value: ApiConfig.baseUrl.isEmpty
                      ? '(tanımlı değil — mock veri)'
                      : ApiConfig.baseUrl,
                ),
                _Row(
                  label: 'Varsayılan timeout',
                  value: '${ApiConfig.timeout.inSeconds} sn',
                ),
              ],
            ),
          ),
          _Section(
            title: 'Yerel veriler',
            child: Column(
              children: [
                _Row(label: 'Yüklü makale', value: '${newsProv.articles.length}'),
                _Row(label: 'Kayıtlı', value: '${bookmarks.count}'),
                _Row(label: 'Okuma geçmişi', value: '${history.count}'),
                _Row(label: 'Arama geçmişi', value: '${search.history.length}'),
              ],
            ),
          ),
          if (_healthBaseInfo != null)
            _Section(
              title: 'Backend',
              child: Column(
                children: [
                  _Row(
                    label: 'Servis',
                    value: '${_healthBaseInfo!['service'] ?? '-'}',
                  ),
                  _Row(
                    label: 'Durum',
                    value: '${_healthBaseInfo!['status'] ?? '-'}',
                  ),
                  _Row(
                    label: 'Sunucu zamanı',
                    value: '${_healthBaseInfo!['time'] ?? '-'}',
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Text(
                  'DIŞ KAYNAKLAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: cs.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final h in _health) _HealthTile(health: h),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.health});
  final _SourceHealth health;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = health.ok ? Colors.green : cs.error;
    return ListTile(
      leading: Icon(
        health.ok ? Icons.check_circle : Icons.cancel,
        color: color,
      ),
      title: Text(
        health.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        health.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        '${health.latencyMs}ms',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
