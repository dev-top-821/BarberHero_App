import 'package:dio/dio.dart';
import 'package:shared_models/shared_models.dart';
import 'config.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio _dio;
  late final AuthInterceptor _authInterceptor;

  ApiClient({ApiConfig config = ApiConfig.development}) {
    _dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _authInterceptor = AuthInterceptor(_dio);
    _dio.interceptors.add(_authInterceptor);
  }

  // ─── Auth ─────────────────────────────────────

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _dio.post('/auth/register', data: request.toJson());
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post('/auth/login', data: request.toJson());
    return AuthResponse.fromJson(response.data);
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    await AuthInterceptor.clearTokens();
  }

  // ─── User ─────────────────────────────────────

  Future<User> getMe() async {
    final response = await _dio.get('/users/me');
    return User.fromJson(response.data['user']);
  }

  Future<void> updateFcmToken(String token) async {
    await _dio.patch('/users/me/fcm-token', data: {'fcmToken': token});
  }

  // ─── Barber Discovery (Customer) ──────────────

  Future<List<NearbyBarber>> getNearbyBarbers({
    required double latitude,
    required double longitude,
    double radiusMiles = 10,
    String? service,
  }) async {
    final response = await _dio.get('/barbers/nearby', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'radiusMiles': radiusMiles,
      if (service != null) 'service': service,
    });
    return (response.data['barbers'] as List)
        .map((b) => NearbyBarber.fromJson(b))
        .toList();
  }

  Future<BarberProfile> getBarberProfile(String id) async {
    final response = await _dio.get('/barbers/$id');
    return BarberProfile.fromJson(response.data['barber']);
  }

  Future<List<Service>> getBarberServices(String barberId) async {
    final response = await _dio.get('/barbers/$barberId/services');
    return (response.data['services'] as List)
        .map((s) => Service.fromJson(s))
        .toList();
  }

  Future<List<String>> getBarberAvailability(String barberId, String date) async {
    final response = await _dio.get('/barbers/$barberId/availability',
        queryParameters: {'date': date});
    return List<String>.from(response.data['availableSlots']);
  }

  // ─── Barber Profile (Barber App) ──────────────

  Future<BarberProfile> getMyBarberProfile() async {
    final response = await _dio.get('/barber/profile');
    return BarberProfile.fromJson(response.data['profile']);
  }

  Future<void> updateBarberProfile(Map<String, dynamic> data) async {
    await _dio.patch('/barber/profile', data: data);
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    await _dio.patch('/barber/profile/online', data: {'isOnline': isOnline});
  }

  // ─── Barber Services ──────────────────────────

  Future<List<Service>> getMyServices() async {
    final response = await _dio.get('/barber/services');
    return (response.data['services'] as List)
        .map((s) => Service.fromJson(s))
        .toList();
  }

  Future<Service> addService(Map<String, dynamic> data) async {
    final response = await _dio.post('/barber/services', data: data);
    return Service.fromJson(response.data['service']);
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _dio.patch('/barber/services/$id', data: data);
  }

  Future<void> deleteService(String id) async {
    await _dio.delete('/barber/services/$id');
  }

  // ─── Barber Availability ──────────────────────

  Future<List<AvailabilitySlot>> getMyAvailability() async {
    final response = await _dio.get('/barber/availability');
    return (response.data['slots'] as List)
        .map((s) => AvailabilitySlot.fromJson(s))
        .toList();
  }

  Future<void> setAvailability(List<Map<String, dynamic>> slots) async {
    await _dio.put('/barber/availability', data: {'slots': slots});
  }

  // ─── Barber Settings ──────────────────────────

  Future<BarberSettings> getMySettings() async {
    final response = await _dio.get('/barber/settings');
    return BarberSettings.fromJson(response.data['settings']);
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    await _dio.patch('/barber/settings', data: data);
  }

  // ─── Bookings ─────────────────────────────────

  Future<List<Booking>> getBookings({String? status}) async {
    final response = await _dio.get('/bookings',
        queryParameters: {if (status != null) 'status': status});
    return (response.data['bookings'] as List)
        .map((b) => Booking.fromJson(b))
        .toList();
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final response = await _dio.post('/bookings', data: data);
    return response.data;
  }

  Future<void> updateBookingStatus(String id, String status) async {
    await _dio.patch('/bookings/$id/status', data: {'status': status});
  }

  Future<Map<String, dynamic>> verifyBookingCode(String id, String code) async {
    final response =
        await _dio.post('/bookings/$id/verify', data: {'code': code});
    return response.data;
  }

  Future<void> cancelBooking(String id) async {
    await _dio.post('/bookings/$id/cancel');
  }

  // ─── Wallet ───────────────────────────────────

  Future<Wallet> getWallet() async {
    final response = await _dio.get('/wallet');
    return Wallet.fromJson(response.data['wallet']);
  }

  Future<Map<String, dynamic>> withdrawFunds(int amountInPence) async {
    final response = await _dio.post('/wallet/withdraw',
        data: {'amountInPence': amountInPence});
    return response.data;
  }

  // ─── Chat ─────────────────────────────────────

  Future<List<ChatRoom>> getChatRooms() async {
    final response = await _dio.get('/chat/rooms');
    return (response.data['rooms'] as List)
        .map((r) => ChatRoom.fromJson(r))
        .toList();
  }

  Future<List<ChatMessage>> getMessages(String roomId, {String? after}) async {
    final response = await _dio.get('/chat/rooms/$roomId/messages',
        queryParameters: {if (after != null) 'after': after});
    return (response.data['messages'] as List)
        .map((m) => ChatMessage.fromJson(m))
        .toList();
  }

  Future<ChatMessage> sendMessage(String roomId, String content) async {
    final response = await _dio
        .post('/chat/rooms/$roomId/messages', data: {'content': content});
    return ChatMessage.fromJson(response.data['message']);
  }
}
