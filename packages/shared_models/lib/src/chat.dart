import 'package:json_annotation/json_annotation.dart';

part 'chat.g.dart';

@JsonSerializable()
class ChatRoom {
  final String id;
  final String bookingId;
  final ChatParticipant? customer;
  final ChatParticipant? barber;
  final ChatMessage? lastMessage;
  // Count of messages authored by the other party since the current user
  // last opened this room.
  final int? unreadCount;
  // The peer's last-read timestamp — used on the conversation screen to
  // render "Seen" markers on messages the current user has sent.
  final DateTime? peerLastReadAt;
  final DateTime? createdAt;

  ChatRoom({
    required this.id,
    required this.bookingId,
    this.customer,
    this.barber,
    this.lastMessage,
    this.unreadCount,
    this.peerLastReadAt,
    this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) =>
      _$ChatRoomFromJson(json);
  Map<String, dynamic> toJson() => _$ChatRoomToJson(this);
}

@JsonSerializable()
class ChatParticipant {
  final String id;
  final String fullName;
  final String? profilePhoto;

  ChatParticipant({
    required this.id,
    required this.fullName,
    this.profilePhoto,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) =>
      _$ChatParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$ChatParticipantToJson(this);
}

@JsonSerializable()
class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String content;
  final ChatSender? sender;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    this.sender,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
}

@JsonSerializable()
class ChatSender {
  final String id;
  final String fullName;

  ChatSender({required this.id, required this.fullName});

  factory ChatSender.fromJson(Map<String, dynamic> json) =>
      _$ChatSenderFromJson(json);
  Map<String, dynamic> toJson() => _$ChatSenderToJson(this);
}
