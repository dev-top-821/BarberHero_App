import 'package:json_annotation/json_annotation.dart';

part 'booking.g.dart';

@JsonSerializable()
class Booking {
  final String id;
  final String customerId;
  final String barberId;
  final DateTime date;
  final String startTime;
  final String status;
  final String address;
  final int totalInPence;
  final BookingCustomer? customer;
  final BookingBarber? barber;
  final List<BookingService>? services;
  final VerificationCode? verificationCode;
  final DateTime? createdAt;

  Booking({
    required this.id,
    required this.customerId,
    required this.barberId,
    required this.date,
    required this.startTime,
    required this.status,
    required this.address,
    required this.totalInPence,
    this.customer,
    this.barber,
    this.services,
    this.verificationCode,
    this.createdAt,
  });

  double get totalInPounds => totalInPence / 100.0;

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);
  Map<String, dynamic> toJson() => _$BookingToJson(this);
}

@JsonSerializable()
class BookingCustomer {
  final String fullName;
  final String? profilePhoto;
  // Server only returns a non-null value once the booking reaches
  // ON_THE_WAY (see Barber_Admin/src/lib/booking-privacy.ts).
  final String? phone;

  BookingCustomer({required this.fullName, this.profilePhoto, this.phone});

  factory BookingCustomer.fromJson(Map<String, dynamic> json) =>
      _$BookingCustomerFromJson(json);
  Map<String, dynamic> toJson() => _$BookingCustomerToJson(this);
}

@JsonSerializable()
class BookingBarber {
  final BookingBarberUser? user;

  BookingBarber({this.user});

  factory BookingBarber.fromJson(Map<String, dynamic> json) =>
      _$BookingBarberFromJson(json);
  Map<String, dynamic> toJson() => _$BookingBarberToJson(this);
}

@JsonSerializable()
class BookingBarberUser {
  final String fullName;
  final String? profilePhoto;
  // Server only returns a non-null value once the booking reaches
  // ON_THE_WAY (see Barber_Admin/src/lib/booking-privacy.ts).
  final String? phone;

  BookingBarberUser({required this.fullName, this.profilePhoto, this.phone});

  factory BookingBarberUser.fromJson(Map<String, dynamic> json) =>
      _$BookingBarberUserFromJson(json);
  Map<String, dynamic> toJson() => _$BookingBarberUserToJson(this);
}

@JsonSerializable()
class BookingService {
  final String id;
  final String serviceId;
  final int priceInPence;
  final ServiceDetail? service;

  BookingService({
    required this.id,
    required this.serviceId,
    required this.priceInPence,
    this.service,
  });

  factory BookingService.fromJson(Map<String, dynamic> json) =>
      _$BookingServiceFromJson(json);
  Map<String, dynamic> toJson() => _$BookingServiceToJson(this);
}

@JsonSerializable()
class ServiceDetail {
  final String name;
  final int durationMinutes;

  ServiceDetail({required this.name, required this.durationMinutes});

  factory ServiceDetail.fromJson(Map<String, dynamic> json) =>
      _$ServiceDetailFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceDetailToJson(this);
}

@JsonSerializable()
class VerificationCode {
  final String? code;
  final bool isUsed;

  VerificationCode({this.code, required this.isUsed});

  factory VerificationCode.fromJson(Map<String, dynamic> json) =>
      _$VerificationCodeFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationCodeToJson(this);
}
