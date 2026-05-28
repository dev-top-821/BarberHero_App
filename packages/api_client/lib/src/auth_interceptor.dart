import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _cachedUserKey = 'cached_user';

  final Dio _dio;

  AuthInterceptor(this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken != null) {
        try {
          final response = await _dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newAccess = response.data['accessToken'] as String;
          final newRefresh = response.data['refreshToken'] as String;

          await prefs.setString(_accessTokenKey, newAccess);
          await prefs.setString(_refreshTokenKey, newRefresh);

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          await clearTokens();
        }
      }
    }

    handler.next(err);
  }

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_cachedUserKey);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// Cache the serialized user so the next launch can render a signed-in UI
  /// immediately — even before /users/me returns (or when it can't, e.g. the
  /// device is offline). Call on every successful login/register/getMe.
  static Future<void> saveCachedUser(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedUserKey, jsonEncode(userJson));
  }

  /// Returns the last known user JSON, or null if nothing cached.
  static Future<Map<String, dynamic>?> loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
