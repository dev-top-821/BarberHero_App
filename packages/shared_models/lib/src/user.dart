import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? profilePhoto;
  final String role;
  final DateTime? createdAt;
  final BarberProfileSummary? barberProfile;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.profilePhoto,
    required this.role,
    this.createdAt,
    this.barberProfile,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class BarberProfileSummary {
  final String id;
  final String status;
  final bool? isOnline;

  BarberProfileSummary({
    required this.id,
    required this.status,
    this.isOnline,
  });

  factory BarberProfileSummary.fromJson(Map<String, dynamic> json) =>
      _$BarberProfileSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$BarberProfileSummaryToJson(this);
}
