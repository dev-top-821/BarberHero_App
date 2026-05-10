import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'chat_conversation_screen.dart';

/// Barber-side inbox. Subscribes to the user's chat rooms in Firestore for
/// live unread + last-message updates, and cross-references with the REST
/// `/chat/rooms` response for peer (customer) profile data.
class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  StreamSubscription<List<ChatRoomMeta>>? _sub;
  Map<String, ChatRoom> _profilesByRoomId = {};
  List<ChatRoomMeta> _liveRooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    await _loadProfiles();
    if (!mounted) return;
    final realtime = context.read<ChatRealtimeService>();
    final firestoreOk = await realtime.ensureSignedIn();
    if (!mounted) return;
    if (!firestoreOk) {
      setState(() => _loading = false);
      return;
    }
    _sub = realtime.roomsStream(userId).listen(
      (rooms) async {
        if (!mounted) return;
        final missing =
            rooms.any((r) => !_profilesByRoomId.containsKey(r.id));
        setState(() {
          _liveRooms = rooms;
          _loading = false;
          _error = null;
        });
        if (missing) await _loadProfiles();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not load conversations.';
        });
      },
    );
  }

  Future<void> _loadProfiles() async {
    try {
      final api = context.read<ApiClient>();
      final rooms = await api.getChatRooms();
      if (!mounted) return;
      setState(() {
        _profilesByRoomId = {for (final r in rooms) r.id: r};
      });
    } catch (_) {
      if (!mounted) return;
      if (_profilesByRoomId.isEmpty && _liveRooms.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Could not load conversations.';
        });
      }
    }
  }

  void _openRoom(ChatRoom room) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null) return;

    final peer = room.customer; // Peer from a barber's perspective.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          roomId: room.id,
          peerName: peer?.fullName ?? 'Customer',
          peerPhoto: peer?.profilePhoto,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.user?.id;
    final visible = userId == null
        ? const <_DisplayRoom>[]
        : (_liveRooms.isNotEmpty
            ? _liveRooms
                .map((meta) {
                  final profile = _profilesByRoomId[meta.id];
                  if (profile == null) return null;
                  return _DisplayRoom(
                    meta: meta,
                    profile: profile,
                    userId: userId,
                  );
                })
                .whereType<_DisplayRoom>()
                .toList()
            : _profilesByRoomId.values
                .map((profile) => _DisplayRoom(
                      meta: null,
                      profile: profile,
                      userId: userId,
                    ))
                .toList());

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                  )
                : visible.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 76,
                          color: AppColors.border,
                        ),
                        itemBuilder: (_, i) => _RoomTile(
                          display: visible[i],
                          onTap: () => _openRoom(visible[i].profile),
                        ),
                      ),
      ),
    );
  }
}

class _DisplayRoom {
  final ChatRoomMeta? meta;
  final ChatRoom profile;
  final String userId;
  _DisplayRoom({
    required this.meta,
    required this.profile,
    required this.userId,
  });

  int get unreadCount => meta?.unreadFor(userId) ?? profile.unreadCount ?? 0;
  String? get lastMessage => meta?.lastMessage ?? profile.lastMessage?.content;
  DateTime? get lastMessageAt =>
      meta?.lastMessageAt ?? profile.lastMessage?.createdAt;
}

class _RoomTile extends StatelessWidget {
  final _DisplayRoom display;
  final VoidCallback onTap;
  const _RoomTile({required this.display, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final peer = display.profile.customer;
    final name = peer?.fullName ?? 'Customer';
    final unread = display.unreadCount;
    final hasUnread = unread > 0;
    final lastMsg = display.lastMessage;
    final lastAt = display.lastMessageAt;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surface,
        backgroundImage: peer?.profilePhoto != null
            ? CachedNetworkImageProvider(peer!.profilePhoto!)
            : null,
        child: peer?.profilePhoto == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 15,
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        lastMsg ?? 'Say hello',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (lastAt != null)
            Text(
              _formatRelative(lastAt),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread ? AppColors.primary : AppColors.textSecondary,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final delta = now.difference(dt);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    final local = dt.toLocal();
    return '${local.day}/${local.month}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 80),
        Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.border),
        SizedBox(height: 16),
        Text(
          'No conversations yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Chats will appear here once you confirm a booking.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}
