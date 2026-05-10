import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized access to all environment variables.
/// Loaded once in main() via `await dotenv.load()`.
class Env {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000/api/v1';
}
