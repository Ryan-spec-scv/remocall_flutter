import 'dart:convert';
import 'package:remocall_flutter/utils/datetime_utils.dart';

class NotificationModel {
  final int? id;
  final String packageName;
  final String sender;
  final String message;
  final Map<String, dynamic>? parsedData;
  final DateTime receivedAt;
  final bool isSent;
  final DateTime? sentAt;
  final String? errorMessage;
  final bool isServerSent;
  final DateTime? serverSentAt;

  NotificationModel({
    this.id,
    required this.packageName,
    required this.sender,
    required this.message,
    this.parsedData,
    required this.receivedAt,
    this.isSent = false,
    this.sentAt,
    this.errorMessage,
    this.isServerSent = false,
    this.serverSentAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      packageName: json['package_name'],
      sender: json['sender'],
      message: json['message'],
      parsedData: json['parsed_data'] != null
          ? json['parsed_data'] is String 
              ? jsonDecode(json['parsed_data']) 
              : Map<String, dynamic>.from(json['parsed_data'])
          : null,
      receivedAt: DateTimeUtils.parseToKST(json['received_at']),
      isSent: json['is_sent'] == 1 || json['is_sent'] == true,
      sentAt: json['sent_at'] != null ? DateTimeUtils.parseToKST(json['sent_at']) : null,
      errorMessage: json['error_message'],
      isServerSent: json['is_server_sent'] == 1 || json['is_server_sent'] == true,
      serverSentAt: json['server_sent_at'] != null ? DateTimeUtils.parseToKST(json['server_sent_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'package_name': packageName,
      'sender': sender,
      'message': message,
      'parsed_data': parsedData != null ? jsonEncode(parsedData) : null,
      'received_at': receivedAt.toIso8601String(),
      'is_sent': isSent ? 1 : 0,
      'sent_at': sentAt?.toIso8601String(),
      'error_message': errorMessage,
      'is_server_sent': isServerSent ? 1 : 0,
      'server_sent_at': serverSentAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    int? id,
    String? packageName,
    String? sender,
    String? message,
    Map<String, dynamic>? parsedData,
    DateTime? receivedAt,
    bool? isSent,
    DateTime? sentAt,
    String? errorMessage,
    bool? isServerSent,
    DateTime? serverSentAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      parsedData: parsedData ?? this.parsedData,
      receivedAt: receivedAt ?? this.receivedAt,
      isSent: isSent ?? this.isSent,
      sentAt: sentAt ?? this.sentAt,
      errorMessage: errorMessage ?? this.errorMessage,
      isServerSent: isServerSent ?? this.isServerSent,
      serverSentAt: serverSentAt ?? this.serverSentAt,
    );
  }
}