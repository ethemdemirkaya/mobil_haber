import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (!ApiConfig.useApi) {
      throw ApiException('API base URL tanımlı değil');
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    try {
      final response =
          await _client.get(uri).timeout(timeout ?? ApiConfig.timeout);
      return _decode(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Bağlantı hatası: $e');
    }
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body['data'] ?? body;
      }
      return body;
    }
    final message = body is Map && body['error'] is Map
        ? (body['error']['message']?.toString() ?? 'Bilinmeyen hata')
        : 'HTTP ${response.statusCode}';
    throw ApiException(message, statusCode: response.statusCode);
  }

  void close() => _client.close();
}
