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

  /// Record that the current CUSTOMER accepted the Terms & Conditions +
  /// Privacy Policy at the current version. Idempotent.
  Future<void> acceptTerms() async {
    await _dio.post('/accept-terms');
  }

  /// Record that the current BARBER accepted the Terms & Conditions +
  /// Privacy Policy at the current version. Idempotent.
  Future<void> acceptBarberTerms() async {
    await _dio.post('/barber/accept-terms');
  }

  /// Edit the current user's profile. Only the fields you pass are updated.
  /// Returns the fresh `User`.
  Future<User> updateMe({
    String? fullName,
    String? phone,
    String? profilePhoto,
  }) async {
    final response = await _dio.patch('/users/me', data: {
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (profilePhoto != null) 'profilePhoto': profilePhoto,
    });
    return User.fromJson(response.data['user']);
  }

  /// Upload the current user's avatar. Server persists the file to the
  /// photos disk, sets `User.profilePhoto`, and returns the public URL.
  Future<String> uploadUserPhoto(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    final response = await _dio.post('/users/me/photo', data: form);
    return response.data['profilePhoto'] as String;
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

  Future<List<String>> getBarberAvailability(
    String barberId,
    String date, {
    required List<String> serviceIds,
  }) async {
    // Server needs serviceIds to compute total slot duration — a 30-min cut
    // and a 90-min full service produce different bookable start times.
    final response = await _dio.get(
      '/barbers/$barberId/availability',
      queryParameters: {
        'date': date,
        'serviceIds': serviceIds.join(','),
      },
    );
    return List<String>.from(response.data['availableSlots']);
  }

  Future<List<Review>> getBarberReviews(String barberId) async {
    final response = await _dio.get('/barbers/$barberId/reviews');
    return (response.data['reviews'] as List)
        .map((r) => Review.fromJson(r))
        .toList();
  }

  /// Reviews + aggregate for the currently-signed-in barber. Wraps
  /// GET /barber/reviews so the app doesn't need to look up its own
  /// barberProfile id first.
  Future<({List<Review> reviews, double averageRating, int totalReviews})>
      getMyReviews() async {
    final response = await _dio.get('/barber/reviews');
    final reviews = (response.data['reviews'] as List)
        .map((r) => Review.fromJson(r))
        .toList();
    return (
      reviews: reviews,
      averageRating: (response.data['averageRating'] as num).toDouble(),
      totalReviews: (response.data['totalReviews'] as num).toInt(),
    );
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

  // ─── Barber Onboarding (direct multipart uploads to disk) ───

  /// Upload a portfolio photo. Server saves to disk + creates the
  /// `BarberPhoto` row in one call. Returns the created photo record.
  Future<Map<String, dynamic>> uploadBarberPortfolio(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    final response = await _dio.post('/barber/photos', data: form);
    return Map<String, dynamic>.from(response.data['photo']);
  }

  Future<void> deletePortfolioPhoto(String id) async {
    await _dio.delete('/barber/photos/$id');
  }

  /// Upload the barber's face photo. Server saves to disk + sets
  /// `User.profilePhoto`. Returns the public URL.
  Future<String> uploadBarberProfilePhoto(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    final response = await _dio.post('/barber/profile/photo', data: form);
    return response.data['profilePhoto'] as String;
  }

  /// Flips the barber from INCOMPLETE/REJECTED to PENDING for admin review.
  /// Throws [DioException] with the server error body when fields are missing.
  Future<Map<String, dynamic>> submitForReview() async {
    final response = await _dio.post('/barber/submit-for-review');
    return Map<String, dynamic>.from(response.data);
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

  /// Call right after the Stripe PaymentSheet succeeds. Tells the server
  /// the manual-capture hold is in place so it promotes the payment and
  /// notifies the barber (the barber only sees the request from here on).
  /// Best-effort: the `amount_capturable_updated` webhook is the backup
  /// if this call is lost.
  Future<void> confirmBookingPayment(String id) async {
    await _dio.post('/bookings/$id/confirm-payment');
  }

  Future<Map<String, dynamic>> verifyBookingCode(String id, String code) async {
    final response =
        await _dio.post('/bookings/$id/verify', data: {'code': code});
    return response.data;
  }

  Future<void> cancelBooking(String id) async {
    await _dio.post('/bookings/$id/cancel');
  }

  /// Customer-initiated no-show refund: only works if the booking is still
  /// CONFIRMED (no code entered) 30+ minutes after the scheduled start.
  Future<void> reportNoShow(String id) async {
    await _dio.post('/bookings/$id/no-show');
  }

  /// Customer-driven early completion. Releases the barber's pending funds
  /// to `available` immediately and flips the booking to COMPLETED, skipping
  /// the 24h dispute window. Only valid while the booking is STARTED.
  Future<void> completeBooking(String id) async {
    await _dio.post('/bookings/$id/complete');
  }

  Future<Map<String, dynamic>> submitReview(
    String bookingId, {
    required int rating,
    String? comment,
  }) async {
    final response = await _dio.post('/bookings/$bookingId/review', data: {
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> submitReport(
    String bookingId, {
    required String category,
    required String description,
    List<String>? imageUrls,
    bool requestRefund = false,
  }) async {
    final response = await _dio.post('/bookings/$bookingId/report', data: {
      'category': category,
      'description': description,
      if (imageUrls != null) 'imageUrls': imageUrls,
      if (requestRefund) 'requestRefund': true,
    });
    return response.data;
  }

  /// Upload a single photo for a dispute report. Returns the public URL
  /// to collect + submit alongside the report body.
  Future<String> uploadReportImage(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    final response = await _dio.post('/uploads/report-image', data: form);
    return response.data['url'] as String;
  }

  // ─── Wallet ───────────────────────────────────

  Future<
      ({
        Wallet wallet,
        DateTime? nextAutoPayoutAt,
        int withdrawalFeeInPence,
        int minWithdrawalInPence,
      })> getWallet() async {
    final response = await _dio.get('/wallet');
    final next = response.data['nextAutoPayoutAt'] as String?;
    return (
      wallet: Wallet.fromJson(response.data['wallet']),
      nextAutoPayoutAt: next != null ? DateTime.parse(next) : null,
      withdrawalFeeInPence:
          (response.data['withdrawalFeeInPence'] as num?)?.toInt() ?? 0,
      minWithdrawalInPence:
          (response.data['minWithdrawalInPence'] as num?)?.toInt() ?? 1000,
    );
  }

  Future<Map<String, dynamic>> withdrawFunds(int amountInPence) async {
    final response = await _dio.post('/wallet/withdraw',
        data: {'amountInPence': amountInPence});
    return response.data;
  }

  // ─── Bank details (barber) ────────────────────

  /// Read the barber's saved bank details. Returns `{ bankAccountName,
  /// bankSortCode, bankAccountNumber }` — any field may be null.
  Future<Map<String, String?>> getBankAccount() async {
    final response = await _dio.get('/barber/bank-account');
    final data = response.data as Map;
    return {
      'bankAccountName': data['bankAccountName'] as String?,
      'bankSortCode': data['bankSortCode'] as String?,
      'bankAccountNumber': data['bankAccountNumber'] as String?,
    };
  }

  /// Save the barber's bank details. All three fields are required together.
  Future<void> updateBankAccount({
    required String bankAccountName,
    required String bankSortCode,
    required String bankAccountNumber,
  }) async {
    await _dio.patch('/barber/bank-account', data: {
      'bankAccountName': bankAccountName,
      'bankSortCode': bankSortCode,
      'bankAccountNumber': bankAccountNumber,
    });
  }

  // ─── Chat ─────────────────────────────────────

  Future<List<ChatRoom>> getChatRooms() async {
    final response = await _dio.get('/chat/rooms');
    return (response.data['rooms'] as List)
        .map((r) => ChatRoom.fromJson(r))
        .toList();
  }

  /// Fetch messages plus the peer's last-read timestamp (for "Seen" markers).
  /// Pass [after] (ISO-8601) to fetch only messages created after that time —
  /// used by the conversation screen's 15s polling loop.
  Future<({List<ChatMessage> messages, DateTime? peerLastReadAt})>
      getMessages(String roomId, {String? after}) async {
    final response = await _dio.get('/chat/rooms/$roomId/messages',
        queryParameters: {if (after != null) 'after': after});
    final messages = (response.data['messages'] as List)
        .map((m) => ChatMessage.fromJson(m))
        .toList();
    final peerRaw = response.data['peerLastReadAt'] as String?;
    return (
      messages: messages,
      peerLastReadAt: peerRaw == null ? null : DateTime.parse(peerRaw),
    );
  }

  Future<ChatMessage> sendMessage(String roomId, String content) async {
    final response = await _dio
        .post('/chat/rooms/$roomId/messages', data: {'content': content});
    return ChatMessage.fromJson(response.data['message']);
  }

  /// Stamp the current user's last-read timestamp on this room. Resets the
  /// inbox unread count to zero and updates "Seen" markers on the peer's side.
  Future<void> markChatRoomRead(String roomId) async {
    await _dio.post('/chat/rooms/$roomId/read');
  }

  /// Page of older messages for users scrolling past the Firestore live
  /// cache. Returns ascending order (oldest → newest) so callers can
  /// prepend directly to their displayed list.
  Future<({List<ChatMessage> messages, bool hasMore})> getMessageHistory(
    String roomId, {
    required DateTime before,
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/chat/rooms/$roomId/history',
      queryParameters: {
        'before': before.toUtc().toIso8601String(),
        'limit': limit,
      },
    );
    final messages = (response.data['messages'] as List)
        .map((m) => ChatMessage.fromJson(m))
        .toList();
    final hasMore = response.data['hasMore'] as bool? ?? false;
    return (messages: messages, hasMore: hasMore);
  }

  /// Mints a Firebase Auth custom token for the current user. Used by the
  /// real-time chat layer to sign into Firebase Auth so security rules can
  /// identify them as a chat-room participant.
  Future<String> getFirebaseToken() async {
    final response = await _dio.post('/users/me/firebase-token');
    return response.data['token'] as String;
  }
}
