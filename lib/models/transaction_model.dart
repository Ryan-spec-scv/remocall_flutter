import 'package:remocall_flutter/utils/datetime_utils.dart';

enum TransactionType {
  income,
  expense,
  transfer,
  payment,
  cancel,
  unknown,
}

enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

class TransactionModel {
  final String? id;
  final TransactionType type;
  final double amount;
  final String description;
  final String? sender;
  final String? receiver;
  final String category;
  final DateTime createdAt;
  final TransactionStatus status;
  final String? account;
  final double? balance;
  final bool isSynced;
  final String? rawMessage;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.sender,
    this.receiver,
    required this.category,
    required this.createdAt,
    this.status = TransactionStatus.completed,
    this.account,
    this.balance,
    this.isSynced = false,
    this.rawMessage,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      type: _parseTransactionType(json['type']),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      sender: json['sender'],
      receiver: json['receiver'],
      category: json['category'],
      createdAt: DateTimeUtils.parseToKST(json['created_at']),
      status: _parseTransactionStatus(json['status']),
      account: json['account'],
      balance: json['balance'] != null ? (json['balance'] as num).toDouble() : null,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      rawMessage: json['raw_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'description': description,
      'sender': sender,
      'receiver': receiver,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
      'account': account,
      'balance': balance,
      'is_synced': isSynced ? 1 : 0,
      'raw_message': rawMessage,
    };
  }

  TransactionModel copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? description,
    String? sender,
    String? receiver,
    String? category,
    DateTime? createdAt,
    TransactionStatus? status,
    String? account,
    double? balance,
    bool? isSynced,
    String? rawMessage,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      account: account ?? this.account,
      balance: balance ?? this.balance,
      isSynced: isSynced ?? this.isSynced,
      rawMessage: rawMessage ?? this.rawMessage,
    );
  }

  static TransactionType _parseTransactionType(String? type) {
    switch (type) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      case 'payment':
        return TransactionType.payment;
      case 'cancel':
        return TransactionType.cancel;
      default:
        return TransactionType.unknown;
    }
  }

  static TransactionStatus _parseTransactionStatus(String? status) {
    switch (status) {
      case 'pending':
        return TransactionStatus.pending;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.completed;
    }
  }
}