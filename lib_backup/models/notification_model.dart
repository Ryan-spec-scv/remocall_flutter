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
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      packageName: json['package_name'],
      sender: json['sender'],
      message: json['message'],
      parsedData: json['parsed_data'] != null
          ? Map<String, dynamic>.from(json['parsed_data'])
          : null,
      receivedAt: DateTime.parse(json['received_at']),
      isSent: json['is_sent'] ?? false,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'package_name': packageName,
      'sender': sender,
      'message': message,
      'parsed_data': parsedData,
      'received_at': receivedAt.toIso8601String(),
      'is_sent': isSent,
      'sent_at': sentAt?.toIso8601String(),
      'error_message': errorMessage,
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
    );
  }
}