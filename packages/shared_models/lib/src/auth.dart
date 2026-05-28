import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'auth.g.dart';

@JsonSerializable()
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable(includeIfNull: false)
class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final String role;
  final String? postcode;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.role,
    this.postcode,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}
