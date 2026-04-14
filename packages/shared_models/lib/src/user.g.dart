// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  fullName: json['fullName'] as String,
  phone: json['phone'] as String?,
  profilePhoto: json['profilePhoto'] as String?,
  role: json['role'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  barberProfile: json['barberProfile'] == null
      ? null
      : BarberProfileSummary.fromJson(
          json['barberProfile'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'profilePhoto': instance.profilePhoto,
  'role': instance.role,
  'createdAt': instance.createdAt?.toIso8601String(),
  'barberProfile': instance.barberProfile,
};

BarberProfileSummary _$BarberProfileSummaryFromJson(
  Map<String, dynamic> json,
) => BarberProfileSummary(
  id: json['id'] as String,
  status: json['status'] as String,
  isOnline: json['isOnline'] as bool?,
);

Map<String, dynamic> _$BarberProfileSummaryToJson(
  BarberProfileSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'isOnline': instance.isOnline,
};
