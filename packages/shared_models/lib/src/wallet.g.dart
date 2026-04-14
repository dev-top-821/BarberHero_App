// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Wallet _$WalletFromJson(Map<String, dynamic> json) => Wallet(
  id: json['id'] as String,
  balanceInPence: (json['balanceInPence'] as num).toInt(),
  transactions: (json['transactions'] as List<dynamic>?)
      ?.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$WalletToJson(Wallet instance) => <String, dynamic>{
  'id': instance.id,
  'balanceInPence': instance.balanceInPence,
  'transactions': instance.transactions,
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
