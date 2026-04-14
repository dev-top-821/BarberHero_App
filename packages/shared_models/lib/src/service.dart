import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable()
class Service {
  final String id;
  final String name;
  final int durationMinutes;
  final int priceInPence;
  final bool? isActive;

  Service({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.priceInPence,
    this.isActive,
  });

  double get priceInPounds => priceInPence / 100.0;

  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceToJson(this);
}
