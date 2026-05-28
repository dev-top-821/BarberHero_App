import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:api_client/api_client.dart';

import '../screens/chat/chat_rooms_screen.dart';
import '../screens/chat/chat_conversation_screen.dart';

/// Handles FCM push notification setup, permission, token registration,
/// and foreground/background message display.
///
/// Usage:
///   1. Add google-services.json (Android) and GoogleService-Info.plist (iOS)
///   2. Wire [navigatorKey] into MaterialApp.navigatorKey so taps can
///      drive navigation from outside the widget tree.
///   3. Call `NotificationService.init(apiClient)` in main() after
///      Firebase.initializeApp().
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Global navigator key — wire into MaterialApp.navigatorKey.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Cached ApiClient — needed by the tap handler, which can't read from
  /// the widget tree. Set during init() and kept for deep-link lookups.
  static ApiClient? _api;

  /// Tracks the currently-open chat room so an incoming FCM push for it
  /// doesn't shove another conversation screen on top.
  static String? activeChatRoomId;

  static const _channelId = 'barberhero_pro_bookings';
  static const _channelName = 'Booking Requests';
  static const _channelDesc = 'Notifications for new bookings and status changes';

  /// Initialize notifications. Call after Firebase.initializeApp().
  static Future<void> init(ApiClient api) async {
    _api = api;

    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Setup local notification channel (Android)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // iOS won't issue an FCM token until the APNS token is set. Calling
    // getToken() too early returns null (or throws) on iOS — which is why
    // iOS devices never registered while Android did. Wait for the APNS
    // token first, polling briefly since it isn't ready immediately.
    if (Platform.isIOS) {
      var apnsToken = await _messaging.getAPNSToken();
      var retries = 0;
      while (apnsToken == null && retries < 5) {
        await Future.delayed(const Duration(seconds: 1));
        apnsToken = await _messaging.getAPNSToken();
        retries++;
      }
    }

    // Get FCM token and register with backend
    String? token;
    try {
      token = await _messaging.getToken();
    } catch (_) {
      // iOS can still throw if APNS isn't ready; onTokenRefresh will retry.
      token = null;
    }
    // TEMP DIAGNOSTIC — remove before final release. Prints the device's
    // real FCM token so it can be tested directly, bypassing the backend/DB.
    // ignore: avoid_print
    print('FCM_TOKEN_DIAG=$token');
    if (token != null) {
      try {
        await api.updateFcmToken(token);
      } catch (_) {
        // Silently fail — token will be retried on next launch
      }
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await api.updateFcmToken(newToken);
      } catch (_) {}
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Handle background tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Handle terminated-state tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = message.data['type'] as String?;
    switch (type) {
      case 'chat_message':
        final roomId = message.data['chatRoomId'] as String?;
        if (roomId != null) {
          if (activeChatRoomId == roomId) return;
          unawaited(_openChatConversation(roomId));
          return;
        }
        // Missing id — fall back to the inbox.
        nav.push(MaterialPageRoute(builder: (_) => const ChatRoomsScreen()));
        return;
      case 'booking_status':
      case 'booking_request':
        // Dashboard is the bookings list for barbers — replace stack.
        nav.pushNamedAndRemoveUntil('/dashboard', (_) => false);
        return;
      case 'application_status':
        // Splash re-checks status and routes accordingly (approved →
        // /dashboard, rejected → /rejected).
        nav.pushNamedAndRemoveUntil('/', (_) => false);
        return;
      default:
        nav.pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  static Future<void> _openChatConversation(String roomId) async {
    final nav = navigatorKey.currentState;
    final api = _api;
    if (nav == null || api == null) return;

    try {
      final rooms = await api.getChatRooms();
      final match = rooms.where((r) => r.id == roomId).toList();
      if (match.isEmpty) {
        nav.push(MaterialPageRoute(builder: (_) => const ChatRoomsScreen()));
        return;
      }
      final room = match.first;

      final cachedUser = await AuthInterceptor.loadCachedUser();
      final currentUserId = cachedUser?['id'] as String?;
      if (currentUserId == null) {
        nav.push(MaterialPageRoute(builder: (_) => const ChatRoomsScreen()));
        return;
      }

      // Inbox underneath so Back returns to the list.
      nav.push(MaterialPageRoute(builder: (_) => const ChatRoomsScreen()));
      nav.push(MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          roomId: room.id,
          peerName: room.customer?.fullName ?? 'Customer',
          peerPhoto: room.customer?.profilePhoto,
          currentUserId: currentUserId,
        ),
      ));
    } catch (_) {
      nav.push(MaterialPageRoute(builder: (_) => const ChatRoomsScreen()));
    }
  }
}

/// Top-level background message handler.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are handled by the system notification tray.
  // No custom logic needed unless you want to update local state.
}
