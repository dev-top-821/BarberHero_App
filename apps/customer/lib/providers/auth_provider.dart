import 'dart:async';

import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_models/shared_models.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;

  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._api);

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> checkAuth() async {
    final hasToken = await AuthInterceptor.hasToken();
    if (!hasToken) return false;

    // Hydrate from cache first so the UI can proceed even if /users/me
    // fails (offline, server down). The interceptor clears tokens on a
    // hard 401, so reaching here means we still have a valid refresh.
    final cached = await AuthInterceptor.loadCachedUser();
    if (cached != null) {
      try {
        _user = User.fromJson(cached);
        notifyListeners();
      } catch (_) {
        // Corrupt cache — ignore, fall through to the network call.
      }
    }

    try {
      final fresh = await _api.getMe();
      _user = fresh;
      await AuthInterceptor.saveCachedUser(fresh.toJson());
      notifyListeners();
      unawaited(NotificationService.init(_api));
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Refresh flow already failed inside the interceptor — session is
        // genuinely dead.
        await AuthInterceptor.clearTokens();
        _user = null;
        notifyListeners();
        return false;
      }
      // Network / timeout / server error — keep the cached session.
      if (_user != null) {
        unawaited(NotificationService.init(_api));
        return true;
      }
      return false;
    } catch (_) {
      // Non-Dio error — same policy: keep cached user if we have one.
      return _user != null;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(
        LoginRequest(email: email, password: password),
      );
      await AuthInterceptor.saveTokens(response.accessToken, response.refreshToken);
      await AuthInterceptor.saveCachedUser(response.user.toJson());
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      unawaited(NotificationService.init(_api));
      return true;
    } catch (e) {
      _isLoading = false;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String fullName,
    String email,
    String phone,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.register(
        RegisterRequest(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
          role: 'CUSTOMER',
        ),
      );
      await AuthInterceptor.saveTokens(response.accessToken, response.refreshToken);
      await AuthInterceptor.saveCachedUser(response.user.toJson());
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      unawaited(NotificationService.init(_api));
      return true;
    } catch (e) {
      _isLoading = false;
      _error = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Clear tokens even if server call fails
      await AuthInterceptor.clearTokens();
    }
    _user = null;
    notifyListeners();
  }

  /// Re-fetch /users/me and update in-place. Used after mutations (avatar
  /// upload, profile edit) so bound views re-render. Silent on failure —
  /// the caller has usually already shown its own success/error feedback.
  Future<void> refreshUser() async {
    try {
      final fresh = await _api.getMe();
      _user = fresh;
      await AuthInterceptor.saveCachedUser(fresh.toJson());
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        // Server returns `{ error: { code, message } }` — fall back to a
        // plain `message` field just in case.
        final err = data['error'];
        if (err is Map && err['message'] is String) return err['message'] as String;
        if (data['message'] is String) return data['message'] as String;
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Server is taking too long to respond. Check your connection.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach the server. Check your internet or API URL.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
