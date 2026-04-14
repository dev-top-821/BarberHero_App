// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatRoom _$ChatRoomFromJson(Map<String, dynamic> json) => ChatRoom(
  id: json['id'] as String,
  bookingId: json['bookingId'] as String,
  customer: json['customer'] == null
      ? null
      : ChatParticipant.fromJson(json['customer'] as Map<String, dynamic>),
  barber: json['barber'] == null
      ? null
      : ChatParticipant.fromJson(json['barber'] as Map<String, dynamic>),
  lastMessage: json['lastMessage'] == null
      ? null
      : ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ChatRoomToJson(ChatRoom instance) => <String, dynamic>{
  'id': instance.id,
  'bookingId': instance.bookingId,
  'customer': instance.customer,
  'barber': instance.barber,
  'lastMessage': instance.lastMessage,
  'createdAt': instance.createdAt?.toIso8601String(),
};

ChatParticipant _$ChatParticipantFromJson(Map<String, dynamic> json) =>
    ChatParticipant(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );

Map<String, dynamic> _$ChatParticipantToJson(ChatParticipant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'profilePhoto': instance.profilePhoto,
    };

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  chatRoomId: json['chatRoomId'] as String,
  senderId: json['senderId'] as String,
  content: json['content'] as String,
  sender: json['sender'] == null
      ? null
      : ChatSender.fromJson(json['sender'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chatRoomId': instance.chatRoomId,
      'senderId': instance.senderId,
      'content': instance.content,
      'sender': instance.sender,
      'createdAt': instance.createdAt.toIso8601String(),
    };

ChatSender _$ChatSenderFromJson(Map<String, dynamic> json) =>
    ChatSender(id: json['id'] as String, fullName: json['fullName'] as String);

Map<String, dynamic> _$ChatSenderToJson(ChatSender instance) =>
    <String, dynamic>{'id': instance.id, 'fullName': instance.fullName};
