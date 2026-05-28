import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_models/shared_models.dart';

import 'client.dart';

/// Real-time chat service. Postgres (via [ApiClient]) is the system of
/// record — sends and read-receipts still go through REST so the backend
/// can run its auth + business logic + dual-write to Firestore. This
/// service only consumes Firestore for live snapshots and signs the user
/// into Firebase Auth using a backend-minted custom token.
///
/// Firestore data shape (mirrored from the backend):
///   chatRooms/{roomId}
///     participants: [customerId, barberId]
///     customerId, barberId
///     lastMessage, lastMessageAt, lastSenderId
///     unread_<userId>: int
///     customerLastReadAt, barberLastReadAt
///   chatRooms/{roomId}/messages/{messageId}
///     id, senderId, content, createdAt
class ChatRealtimeService {
  final ApiClient _api;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  Future<bool>? _signInFuture;

  /// Set to false after the first failed sign-in (e.g. backend deploy without
  /// the firebase-token endpoint, Firebase Admin not configured server-side,
  /// or Firestore not yet provisioned). Callers should treat this as "no
  /// real-time backend available" and fall back to REST polling.
  bool _firestoreAvailable = true;
  bool get isFirestoreAvailable => _firestoreAvailable;

  ChatRealtimeService(
    this._api, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Try to sign into Firebase Auth using a custom token from the backend.
  /// Returns true on success, false if Firestore real-time is unavailable
  /// (caller should fall back to REST). Never throws — failure is a normal
  /// state during the rollout window before Firestore is configured.
  ///
  /// Idempotent + concurrency-safe: parallel callers share one in-flight
  /// future, and a successful sign-in short-circuits subsequent calls.
  Future<bool> ensureSignedIn() async {
    if (!_firestoreAvailable) return false;
    if (_auth.currentUser != null) return true;
    return _signInFuture ??=
        _doSignIn().whenComplete(() => _signInFuture = null);
  }

  Future<bool> _doSignIn() async {
    try {
      final token = await _api.getFirebaseToken();
      await _auth.signInWithCustomToken(token);
      return true;
    } catch (_) {
      // Could be 404 (endpoint not deployed), 503 (Admin SDK unconfigured),
      // network issue, or sign-in error. In every case, the chat UI should
      // degrade to REST polling rather than show a hard error.
      _firestoreAvailable = false;
      return false;
    }
  }

  /// Sign out of Firebase Auth. Call on app logout so the next user doesn't
  /// inherit the previous user's Firestore identity.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Live stream of messages in a room, ordered by createdAt ascending. Pulls
  /// the most recent [limit] messages — older history is fetched separately
  /// via [loadHistoryBefore].
  Stream<List<ChatMessage>> messagesStream(String roomId, {int limit = 50}) {
    return _firestore
        .collection('chatRooms/$roomId/messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => _messageFromDoc(roomId, d)).toList();
      // Reverse to ascending so the UI can append/scroll-to-bottom naturally.
      return docs.reversed.toList();
    });
  }

  /// Live stream of the room metadata document — drives last-message preview,
  /// unread count, and lastReadAt timestamps for "Seen" markers.
  Stream<ChatRoomMeta?> roomMetaStream(String roomId) {
    return _firestore.doc('chatRooms/$roomId').snapshots().map((snap) {
      if (!snap.exists) return null;
      return ChatRoomMeta.fromFirestore(snap.id, snap.data()!);
    });
  }

  /// Live stream of all rooms the given user participates in. Sorted by the
  /// most recent activity (lastMessageAt desc, falling back to createdAt for
  /// brand-new rooms).
  Stream<List<ChatRoomMeta>> roomsStream(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final rooms = snap.docs
          .map((d) => ChatRoomMeta.fromFirestore(d.id, d.data()))
          .toList();
      rooms.sort((a, b) {
        final at = a.lastMessageAt ?? a.createdAt;
        final bt = b.lastMessageAt ?? b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return rooms;
    });
  }

  /// Fetch a page of older messages from Postgres (backend) for users
  /// scrolling past the Firestore real-time window. [before] is the
  /// createdAt of the oldest message currently displayed.
  Future<({List<ChatMessage> messages, bool hasMore})> loadHistoryBefore(
    String roomId, {
    required DateTime before,
    int limit = 50,
  }) {
    return _api.getMessageHistory(roomId, before: before, limit: limit);
  }

  static ChatMessage _messageFromDoc(
    String roomId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final createdAt = created is Timestamp
        ? created.toDate()
        : created is DateTime
            ? created
            : DateTime.now();
    return ChatMessage(
      id: (data['id'] as String?) ?? doc.id,
      chatRoomId: roomId,
      senderId: data['senderId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}

/// Lightweight projection of the chatRooms/{roomId} Firestore document.
/// Distinct from [ChatRoom] (the REST/Postgres-shaped model) because the
/// Firestore mirror only carries the fields needed for live UI updates.
class ChatRoomMeta {
  final String id;
  final List<String> participants;
  final String? customerId;
  final String? barberId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, int> unreadByUser;
  final DateTime? customerLastReadAt;
  final DateTime? barberLastReadAt;
  final DateTime? createdAt;

  ChatRoomMeta({
    required this.id,
    required this.participants,
    this.customerId,
    this.barberId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadByUser = const {},
    this.customerLastReadAt,
    this.barberLastReadAt,
    this.createdAt,
  });

  factory ChatRoomMeta.fromFirestore(String id, Map<String, dynamic> data) {
    final unread = <String, int>{};
    data.forEach((k, v) {
      if (k.startsWith('unread_') && v is num) {
        unread[k.substring('unread_'.length)] = v.toInt();
      }
    });
    DateTime? toDate(dynamic v) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    return ChatRoomMeta(
      id: id,
      participants:
          (data['participants'] as List?)?.cast<String>() ?? const <String>[],
      customerId: data['customerId'] as String?,
      barberId: data['barberId'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: toDate(data['lastMessageAt']),
      lastSenderId: data['lastSenderId'] as String?,
      unreadByUser: unread,
      customerLastReadAt: toDate(data['customerLastReadAt']),
      barberLastReadAt: toDate(data['barberLastReadAt']),
      createdAt: toDate(data['createdAt']),
    );
  }

  int unreadFor(String userId) => unreadByUser[userId] ?? 0;

  /// The peer's last-read timestamp from [userId]'s perspective. Drives
  /// "Seen" markers on the conversation screen.
  DateTime? peerLastReadAtFor(String userId) {
    if (userId == customerId) return barberLastReadAt;
    if (userId == barberId) return customerLastReadAt;
    return null;
  }
}
