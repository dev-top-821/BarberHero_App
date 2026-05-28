class ApiConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  static const staging = ApiConfig(
    baseUrl: 'https://barberhero-staging.onrender.com/api/v1',
  );

  static const production = ApiConfig(
    baseUrl: 'https://barberhero.onrender.com/api/v1',
  );

  static const development = ApiConfig(
    baseUrl: 'http://10.0.2.2:3000/api/v1',
  );

  /// Create a config from a custom base URL (e.g., from .env).
  factory ApiConfig.fromUrl(String baseUrl) => ApiConfig(baseUrl: baseUrl);
}
