import 'package:json_annotation/json_annotation.dart';

part 'review.g.dart';

@JsonSerializable()
class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final ReviewCustomer? customer;

  Review({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.customer,
  });

  factory Review.fromJson(Map<String, dynamic> json) =>
      _$ReviewFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewToJson(this);
}

@JsonSerializable()
class ReviewCustomer {
  final String fullName;
  final String? profilePhoto;

  ReviewCustomer({required this.fullName, this.profilePhoto});

  factory ReviewCustomer.fromJson(Map<String, dynamic> json) =>
      _$ReviewCustomerFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewCustomerToJson(this);
}
