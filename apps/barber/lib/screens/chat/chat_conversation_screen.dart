import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../config/theme.dart';
import '../../services/notification_service.dart';

/// One-on-one conversation between barber and customer. Streams live
/// messages from Firestore (mirrored from Postgres). Older messages outside
/// the Firestore window are paginated from the backend on demand. Sends go
/// through REST so the backend can dual-write + push.
class ChatConversationScreen extends StatefulWidget {
  final String roomId;
  final String peerName;
  final String? peerPhoto;
  final String currentUserId;

  const ChatConversationScreen({
    super.key,
    required this.roomId,
    required this.peerName,
    required this.currentUserId,
    this.peerPhoto,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  static const _restPollInterval = Duration(seconds: 15);

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessage> _olderHistory = [];
  StreamSubscription<List<ChatMessage>>? _msgSub;
  StreamSubscription<ChatRoomMeta?>? _metaSub;

  // REST-fallback state when Firestore real-time is unavailable.
  Timer? _pollTimer;
  bool _useRestFallback = false;

  List<ChatMessage> _liveMessages = [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMoreHistory = true;
  String? _loadError;
  DateTime? _peerLastReadAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.activeChatRoomId = widget.roomId;
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    if (NotificationService.activeChatRoomId == widget.roomId) {
      NotificationService.activeChatRoomId = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _msgSub?.cancel();
    _metaSub?.cancel();
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_useRestFallback) return;
    if (state == AppLifecycleState.resumed) {
      _pollTimer ??= Timer.periodic(_restPollInterval, (_) => _restPoll());
      _restPoll();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _bootstrap() async {
    final realtime = context.read<ChatRealtimeService>();
    final api = context.read<ApiClient>();

    final firestoreOk = await realtime.ensureSignedIn();
    if (!mounted) return;

    if (!firestoreOk) {
      _useRestFallback = true;
      await _restLoadInitial();
      return;
    }

    unawaited(api.markChatRoomRead(widget.roomId));

    _msgSub = realtime.messagesStream(widget.roomId).listen(
      (messages) {
        if (!mounted) return;
        final wasAtBottom = _isNearBottom();
        setState(() {
          _liveMessages = messages;
          _loading = false;
          _loadError = null;
        });
        if (_liveMessages.any((m) => m.senderId != widget.currentUserId)) {
          unawaited(api.markChatRoomRead(widget.roomId));
        }
        if (wasAtBottom) _scrollToBottom();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'Could not load messages.';
        });
      },
    );

    _metaSub = realtime.roomMetaStream(widget.roomId).listen((meta) {
      if (!mounted || meta == null) return;
      setState(() {
        _peerLastReadAt = meta.peerLastReadAtFor(widget.currentUserId);
      });
    });
  }

  // ─── REST fallback path ────────────────────────────────────

  Future<void> _restLoadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final fresh = await api.getMessages(widget.roomId);
      if (!mounted) return;
      final wasAtBottom = _isNearBottom();
      setState(() {
        _liveMessages = fresh.messages;
        _peerLastReadAt = fresh.peerLastReadAt;
        _loading = false;
      });
      _pollTimer ??= Timer.periodic(_restPollInterval, (_) => _restPoll());
      unawaited(api.markChatRoomRead(widget.roomId));
      if (wasAtBottom) _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load messages.';
      });
    }
  }

  Future<void> _restPoll() async {
    if (_liveMessages.isEmpty) {
      await _restLoadInitial();
      return;
    }
    final after = _liveMessages.last.createdAt.toIso8601String();
    try {
      final api = context.read<ApiClient>();
      final fresh = await api.getMessages(widget.roomId, after: after);
      if (!mounted) return;
      setState(() => _peerLastReadAt = fresh.peerLastReadAt);
      if (fresh.messages.isEmpty) return;
      final wasAtBottom = _isNearBottom();
      setState(() => _liveMessages = [..._liveMessages, ...fresh.messages]);
      if (wasAtBottom) _scrollToBottom();
      unawaited(api.markChatRoomRead(widget.roomId));
    } catch (_) {}
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels >= pos.maxScrollExtent - 80;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80 &&
        _hasMoreHistory &&
        !_loadingMore &&
        _allMessages.isNotEmpty) {
      _loadMoreHistory();
    }
  }

  Future<void> _loadMoreHistory() async {
    setState(() => _loadingMore = true);
    try {
      final all = _allMessages;
      final oldest = all.first.createdAt;
      final api = context.read<ApiClient>();
      final page =
          await api.getMessageHistory(widget.roomId, before: oldest, limit: 50);
      if (!mounted) return;
      setState(() {
        _olderHistory.insertAll(0, page.messages);
        _hasMoreHistory = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<ChatMessage> get _allMessages {
    if (_olderHistory.isEmpty) return _liveMessages;
    final seen = <String>{for (final m in _liveMessages) m.id};
    final merged = <ChatMessage>[];
    for (final m in _olderHistory) {
      if (!seen.contains(m.id)) merged.add(m);
    }
    merged.addAll(_liveMessages);
    return merged;
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputController.clear();
    try {
      final api = context.read<ApiClient>();
      await api.sendMessage(widget.roomId, text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _allMessages;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surface,
              backgroundImage: widget.peerPhoto != null
                  ? CachedNetworkImageProvider(widget.peerPhoto!)
                  : null,
              child: widget.peerPhoto == null
                  ? Text(
                      widget.peerName.isNotEmpty
                          ? widget.peerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Text(
                          _loadError!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      )
                    : messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Say hello 👋',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : Builder(builder: (_) {
                            int seenIdx = -1;
                            if (_peerLastReadAt != null) {
                              for (var i = messages.length - 1; i >= 0; i--) {
                                final m = messages[i];
                                if (m.senderId == widget.currentUserId &&
                                    !m.createdAt.isAfter(_peerLastReadAt!)) {
                                  seenIdx = i;
                                  break;
                                }
                              }
                            }
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              itemCount: messages.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (_loadingMore && i == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                final idx = _loadingMore ? i - 1 : i;
                                final m = messages[idx];
                                final fromMe = m.senderId == widget.currentUserId;
                                return _Bubble(
                                  message: m,
                                  fromMe: fromMe,
                                  showSeen: idx == seenIdx,
                                );
                              },
                            );
                          }),
          ),
          _Composer(
            controller: _inputController,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool fromMe;
  final bool showSeen;
  const _Bubble({
    required this.message,
    required this.fromMe,
    this.showSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = fromMe ? AppColors.primary : AppColors.surface;
    final fg = fromMe ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(fromMe ? 14 : 4),
                      bottomRight: Radius.circular(fromMe ? 4 : 14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(fontSize: 14, color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: fromMe ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showSeen)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'Seen',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Message',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          IconButton(
            icon: sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: AppColors.primary),
            onPressed: sending ? null : onSend,
          ),
        ],
      ),
    );
  }
}
