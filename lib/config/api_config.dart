class ApiConfig {
  // Environment-based API URL configuration
  // Local dev: http://localhost:9000
  // Production: https://anderson-express-api.fly.dev
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:9000', // Default to local dev
  );

  static String get baseUrl => _defaultBaseUrl;

  // For debugging
  static bool get isLocalDev => baseUrl.contains('localhost');
  static bool get isProduction => baseUrl.contains('fly.dev');
}
