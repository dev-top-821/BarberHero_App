// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Service _$ServiceFromJson(Map<String, dynamic> json) => Service(
  id: json['id'] as String,
  name: json['name'] as String,
  durationMinutes: (json['durationMinutes'] as num).toInt(),
  priceInPence: (json['priceInPence'] as num).toInt(),
  isActive: json['isActive'] as bool?,
);

Map<String, dynamic> _$ServiceToJson(Service instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'durationMinutes': instance.durationMinutes,
  'priceInPence': instance.priceInPence,
  'isActive': instance.isActive,
};
