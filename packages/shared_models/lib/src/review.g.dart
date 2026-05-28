// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  id: json['id'] as String,
  rating: (json['rating'] as num).toInt(),
  comment: json['comment'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  customer: json['customer'] == null
      ? null
      : ReviewCustomer.fromJson(json['customer'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReviewToJson(Review instance) => <String, dynamic>{
  'id': instance.id,
  'rating': instance.rating,
  'comment': instance.comment,
  'createdAt': instance.createdAt.toIso8601String(),
  'customer': instance.customer,
};

ReviewCustomer _$ReviewCustomerFromJson(Map<String, dynamic> json) =>
    ReviewCustomer(
      fullName: json['fullName'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );

Map<String, dynamic> _$ReviewCustomerToJson(ReviewCustomer instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'profilePhoto': instance.profilePhoto,
    };
