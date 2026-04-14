import 'package:json_annotation/json_annotation.dart';

part 'wallet.g.dart';

@JsonSerializable()
class Wallet {
  final String id;
  final int balanceInPence;
  final List<WalletTransaction>? transactions;

  Wallet({
    required this.id,
    required this.balanceInPence,
    this.transactions,
  });

  double get balanceInPounds => balanceInPence / 100.0;

  factory Wallet.fromJson(Map<String, dynamic> json) =>
      _$WalletFromJson(json);
  Map<String, dynamic> toJson() => _$WalletToJson(this);
}

@JsonSerializable()
class WalletTransaction {
  final String id;
  final String type;
  final int amountInPence;
  final String? description;
  final String? bookingId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amountInPence,
    this.description,
    this.bookingId,
    required this.createdAt,
  });

  double get amountInPounds => amountInPence / 100.0;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$WalletTransactionToJson(this);
}
