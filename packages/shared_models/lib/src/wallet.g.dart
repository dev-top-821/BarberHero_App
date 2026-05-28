// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Wallet _$WalletFromJson(Map<String, dynamic> json) => Wallet(
  id: json['id'] as String,
  availableInPence: (json['availableInPence'] as num).toInt(),
  pendingInPence: (json['pendingInPence'] as num).toInt(),
  transactions: (json['transactions'] as List<dynamic>?)
      ?.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
      .toList(),
  withdrawalRequests: (json['withdrawalRequests'] as List<dynamic>?)
      ?.map((e) => WithdrawalRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$WalletToJson(Wallet instance) => <String, dynamic>{
  'id': instance.id,
  'availableInPence': instance.availableInPence,
  'pendingInPence': instance.pendingInPence,
  'transactions': instance.transactions,
  'withdrawalRequests': instance.withdrawalRequests,
};

WithdrawalRequest _$WithdrawalRequestFromJson(Map<String, dynamic> json) =>
    WithdrawalRequest(
      id: json['id'] as String,
      amountInPence: (json['amountInPence'] as num).toInt(),
      feeInPence: (json['feeInPence'] as num).toInt(),
      netInPence: (json['netInPence'] as num).toInt(),
      status: json['status'] as String,
      bankReference: json['bankReference'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt: json['processedAt'] == null
          ? null
          : DateTime.parse(json['processedAt'] as String),
    );

Map<String, dynamic> _$WithdrawalRequestToJson(WithdrawalRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amountInPence': instance.amountInPence,
      'feeInPence': instance.feeInPence,
      'netInPence': instance.netInPence,
      'status': instance.status,
      'bankReference': instance.bankReference,
      'createdAt': instance.createdAt.toIso8601String(),
      'processedAt': instance.processedAt?.toIso8601String(),
    };

WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) =>
    WalletTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      amountInPence: (json['amountInPence'] as num).toInt(),
      description: json['description'] as String?,
      bookingId: json['bookingId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$WalletTransactionToJson(WalletTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'amountInPence': instance.amountInPence,
      'description': instance.description,
      'bookingId': instance.bookingId,
      'createdAt': instance.createdAt.toIso8601String(),
    };
