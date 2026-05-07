class ApiConfig {
  ApiConfig._();

  /// Build-time override:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const Duration timeout = Duration(seconds: 4);

  static bool get useApi => baseUrl.isNotEmpty;
}
