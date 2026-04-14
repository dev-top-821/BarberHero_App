// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Booking _$BookingFromJson(Map<String, dynamic> json) => Booking(
  id: json['id'] as String,
  customerId: json['customerId'] as String,
  barberId: json['barberId'] as String,
  date: DateTime.parse(json['date'] as String),
  startTime: json['startTime'] as String,
  status: json['status'] as String,
  address: json['address'] as String,
  totalInPence: (json['totalInPence'] as num).toInt(),
  customer: json['customer'] == null
      ? null
      : BookingCustomer.fromJson(json['customer'] as Map<String, dynamic>),
  barber: json['barber'] == null
      ? null
      : BookingBarber.fromJson(json['barber'] as Map<String, dynamic>),
  services: (json['services'] as List<dynamic>?)
      ?.map((e) => BookingService.fromJson(e as Map<String, dynamic>))
      .toList(),
  verificationCode: json['verificationCode'] == null
      ? null
      : VerificationCode.fromJson(
          json['verificationCode'] as Map<String, dynamic>,
        ),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$BookingToJson(Booking instance) => <String, dynamic>{
  'id': instance.id,
  'customerId': instance.customerId,
  'barberId': instance.barberId,
  'date': instance.date.toIso8601String(),
  'startTime': instance.startTime,
  'status': instance.status,
  'address': instance.address,
  'totalInPence': instance.totalInPence,
  'customer': instance.customer,
  'barber': instance.barber,
  'services': instance.services,
  'verificationCode': instance.verificationCode,
  'createdAt': instance.createdAt?.toIso8601String(),
};

BookingCustomer _$BookingCustomerFromJson(Map<String, dynamic> json) =>
    BookingCustomer(
      fullName: json['fullName'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );

Map<String, dynamic> _$BookingCustomerToJson(BookingCustomer instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'profilePhoto': instance.profilePhoto,
    };

BookingBarber _$BookingBarberFromJson(Map<String, dynamic> json) =>
    BookingBarber(
      user: json['user'] == null
          ? null
          : BookingBarberUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BookingBarberToJson(BookingBarber instance) =>
    <String, dynamic>{'user': instance.user};

BookingBarberUser _$BookingBarberUserFromJson(Map<String, dynamic> json) =>
    BookingBarberUser(
      fullName: json['fullName'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );

Map<String, dynamic> _$BookingBarberUserToJson(BookingBarberUser instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'profilePhoto': instance.profilePhoto,
    };

BookingService _$BookingServiceFromJson(Map<String, dynamic> json) =>
    BookingService(
      id: json['id'] as String,
      serviceId: json['serviceId'] as String,
      priceInPence: (json['priceInPence'] as num).toInt(),
      service: json['service'] == null
          ? null
          : ServiceDetail.fromJson(json['service'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BookingServiceToJson(BookingService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serviceId': instance.serviceId,
      'priceInPence': instance.priceInPence,
      'service': instance.service,
    };

ServiceDetail _$ServiceDetailFromJson(Map<String, dynamic> json) =>
    ServiceDetail(
      name: json['name'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
    );

Map<String, dynamic> _$ServiceDetailToJson(ServiceDetail instance) =>
    <String, dynamic>{
      'name': instance.name,
      'durationMinutes': instance.durationMinutes,
    };

VerificationCode _$VerificationCodeFromJson(Map<String, dynamic> json) =>
    VerificationCode(
      code: json['code'] as String?,
      isUsed: json['isUsed'] as bool,
    );

Map<String, dynamic> _$VerificationCodeToJson(VerificationCode instance) =>
    <String, dynamic>{'code': instance.code, 'isUsed': instance.isUsed};
