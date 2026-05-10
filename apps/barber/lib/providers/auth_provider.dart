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

  /// Returns the barber's approval status, or null if not a barber.
  String? get barberStatus => _user?.barberProfile?.status;

  /// Whether the barber's profile has been approved by admin.
  bool get isApproved => barberStatus == 'APPROVED';

  /// Whether the barber is still waiting for admin review.
  bool get isPending => barberStatus == 'PENDING';

  Future<bool> checkAuth() async {
    final hasToken = await AuthInterceptor.hasToken();
    if (!hasToken) return false;

    // Hydrate from cache so startup survives a flaky network.
    final cached = await AuthInterceptor.loadCachedUser();
    if (cached != null) {
      try {
        _user = User.fromJson(cached);
        notifyListeners();
      } catch (_) {
        // Corrupt cache — ignore.
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
        await AuthInterceptor.clearTokens();
        _user = null;
        notifyListeners();
        return false;
      }
      // Network / timeout — stay signed in with cached data.
      if (_user != null) {
        unawaited(NotificationService.init(_api));
        return true;
      }
      return false;
    } catch (_) {
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
    String postcode,
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
          role: 'BARBER',
          postcode: postcode,
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
      await AuthInterceptor.clearTokens();
    }
    _user = null;
    notifyListeners();
  }

  /// Re-fetch `/users/me` and update in-place. Called after actions that
  /// change server-side user state (e.g. submit-for-review flips
  /// barberProfile.status). Silently no-ops on failure — the caller is
  /// about to navigate anyway.
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
