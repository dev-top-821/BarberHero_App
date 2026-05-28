import 'package:json_annotation/json_annotation.dart';
import 'service.dart';

part 'barber_profile.g.dart';

@JsonSerializable()
class BarberProfile {
  final String id;
  final String? bio;
  final String? experience;
  final String status;
  final bool isOnline;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? postcode;
  final String? rejectionReason;
  final BarberUser? user;
  final List<Service>? services;
  final List<BarberPhoto>? photos;
  final BarberSettings? settings;
  final double? rating;
  final int? reviewCount;
  final double? distanceMiles;

  BarberProfile({
    required this.id,
    this.bio,
    this.experience,
    required this.status,
    required this.isOnline,
    this.latitude,
    this.longitude,
    this.address,
    this.postcode,
    this.rejectionReason,
    this.user,
    this.services,
    this.photos,
    this.settings,
    this.rating,
    this.reviewCount,
    this.distanceMiles,
  });

  factory BarberProfile.fromJson(Map<String, dynamic> json) =>
      _$BarberProfileFromJson(json);
  Map<String, dynamic> toJson() => _$BarberProfileToJson(this);
}

@JsonSerializable()
class BarberUser {
  final String fullName;
  final String? profilePhoto;

  BarberUser({required this.fullName, this.profilePhoto});

  factory BarberUser.fromJson(Map<String, dynamic> json) =>
      _$BarberUserFromJson(json);
  Map<String, dynamic> toJson() => _$BarberUserToJson(this);
}

@JsonSerializable()
class BarberPhoto {
  final String id;
  final String url;
  final int order;

  BarberPhoto({required this.id, required this.url, required this.order});

  factory BarberPhoto.fromJson(Map<String, dynamic> json) =>
      _$BarberPhotoFromJson(json);
  Map<String, dynamic> toJson() => _$BarberPhotoToJson(this);
}

@JsonSerializable()
class BarberSettings {
  final double serviceRadiusMiles;
  final int minBookingNoticeHours;

  BarberSettings({
    required this.serviceRadiusMiles,
    required this.minBookingNoticeHours,
  });

  factory BarberSettings.fromJson(Map<String, dynamic> json) =>
      _$BarberSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$BarberSettingsToJson(this);
}

@JsonSerializable()
class AvailabilitySlot {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;

  AvailabilitySlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      _$AvailabilitySlotFromJson(json);
  Map<String, dynamic> toJson() => _$AvailabilitySlotToJson(this);
}

@JsonSerializable()
class NearbyBarber {
  final String id;
  final String fullName;
  final String? profilePhoto;
  final bool isOnline;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final double? rating;
  final int? reviewCount;
  final int? startingPriceInPence;

  NearbyBarber({
    required this.id,
    required this.fullName,
    this.profilePhoto,
    required this.isOnline,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.rating,
    this.reviewCount,
    this.startingPriceInPence,
  });

  factory NearbyBarber.fromJson(Map<String, dynamic> json) =>
      _$NearbyBarberFromJson(json);
  Map<String, dynamic> toJson() => _$NearbyBarberToJson(this);
}
