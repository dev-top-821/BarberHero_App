import 'package:json_annotation/json_annotation.dart';

part 'wallet.g.dart';

@JsonSerializable()
class Wallet {
  final String id;
  final int availableInPence;
  final int pendingInPence;
  final List<WalletTransaction>? transactions;
  final List<WithdrawalRequest>? withdrawalRequests;

  Wallet({
    required this.id,
    required this.availableInPence,
    required this.pendingInPence,
    this.transactions,
    this.withdrawalRequests,
  });

  double get availableInPounds => availableInPence / 100.0;
  double get pendingInPounds => pendingInPence / 100.0;
  double get totalInPounds => (availableInPence + pendingInPence) / 100.0;

  factory Wallet.fromJson(Map<String, dynamic> json) =>
      _$WalletFromJson(json);
  Map<String, dynamic> toJson() => _$WalletToJson(this);
}

@JsonSerializable()
class WithdrawalRequest {
  final String id;
  final int amountInPence;
  final int feeInPence;
  final int netInPence;
  final String status; // REQUESTED / PROCESSING / COMPLETED / FAILED
  final String? bankReference;
  final DateTime createdAt;
  final DateTime? processedAt;

  WithdrawalRequest({
    required this.id,
    required this.amountInPence,
    required this.feeInPence,
    required this.netInPence,
    required this.status,
    this.bankReference,
    required this.createdAt,
    this.processedAt,
  });

  double get amountInPounds => amountInPence / 100.0;
  double get netInPounds => netInPence / 100.0;
  bool get isTerminal => status == 'COMPLETED' || status == 'FAILED';

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      _$WithdrawalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$WithdrawalRequestToJson(this);
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
