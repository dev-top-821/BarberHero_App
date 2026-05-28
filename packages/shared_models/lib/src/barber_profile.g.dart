// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barber_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BarberProfile _$BarberProfileFromJson(Map<String, dynamic> json) =>
    BarberProfile(
      id: json['id'] as String,
      bio: json['bio'] as String?,
      experience: json['experience'] as String?,
      status: json['status'] as String,
      isOnline: json['isOnline'] as bool,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      postcode: json['postcode'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      user: json['user'] == null
          ? null
          : BarberUser.fromJson(json['user'] as Map<String, dynamic>),
      services: (json['services'] as List<dynamic>?)
          ?.map((e) => Service.fromJson(e as Map<String, dynamic>))
          .toList(),
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => BarberPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      settings: json['settings'] == null
          ? null
          : BarberSettings.fromJson(json['settings'] as Map<String, dynamic>),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      distanceMiles: (json['distanceMiles'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$BarberProfileToJson(BarberProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bio': instance.bio,
      'experience': instance.experience,
      'status': instance.status,
      'isOnline': instance.isOnline,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'postcode': instance.postcode,
      'rejectionReason': instance.rejectionReason,
      'user': instance.user,
      'services': instance.services,
      'photos': instance.photos,
      'settings': instance.settings,
      'rating': instance.rating,
      'reviewCount': instance.reviewCount,
      'distanceMiles': instance.distanceMiles,
    };

BarberUser _$BarberUserFromJson(Map<String, dynamic> json) => BarberUser(
  fullName: json['fullName'] as String,
  profilePhoto: json['profilePhoto'] as String?,
);

Map<String, dynamic> _$BarberUserToJson(BarberUser instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'profilePhoto': instance.profilePhoto,
    };

BarberPhoto _$BarberPhotoFromJson(Map<String, dynamic> json) => BarberPhoto(
  id: json['id'] as String,
  url: json['url'] as String,
  order: (json['order'] as num).toInt(),
);

Map<String, dynamic> _$BarberPhotoToJson(BarberPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'order': instance.order,
    };

BarberSettings _$BarberSettingsFromJson(Map<String, dynamic> json) =>
    BarberSettings(
      serviceRadiusMiles: (json['serviceRadiusMiles'] as num).toDouble(),
      minBookingNoticeHours: (json['minBookingNoticeHours'] as num).toInt(),
    );

Map<String, dynamic> _$BarberSettingsToJson(BarberSettings instance) =>
    <String, dynamic>{
      'serviceRadiusMiles': instance.serviceRadiusMiles,
      'minBookingNoticeHours': instance.minBookingNoticeHours,
    };

AvailabilitySlot _$AvailabilitySlotFromJson(Map<String, dynamic> json) =>
    AvailabilitySlot(
      id: json['id'] as String,
      dayOfWeek: json['dayOfWeek'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$AvailabilitySlotToJson(AvailabilitySlot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dayOfWeek': instance.dayOfWeek,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'isActive': instance.isActive,
    };

NearbyBarber _$NearbyBarberFromJson(Map<String, dynamic> json) => NearbyBarber(
  id: json['id'] as String,
  fullName: json['fullName'] as String,
  profilePhoto: json['profilePhoto'] as String?,
  isOnline: json['isOnline'] as bool,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  rating: (json['rating'] as num?)?.toDouble(),
  reviewCount: (json['reviewCount'] as num?)?.toInt(),
  startingPriceInPence: (json['startingPriceInPence'] as num?)?.toInt(),
);

Map<String, dynamic> _$NearbyBarberToJson(NearbyBarber instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'profilePhoto': instance.profilePhoto,
      'isOnline': instance.isOnline,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'distanceKm': instance.distanceKm,
      'rating': instance.rating,
      'reviewCount': instance.reviewCount,
      'startingPriceInPence': instance.startingPriceInPence,
    };
