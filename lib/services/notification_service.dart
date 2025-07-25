import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:remocall_flutter/models/notification_model.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/providers/transaction_provider.dart';

class NotificationService {
  static const platform = MethodChannel('com.remocall/notifications');
  static NotificationService? _instance;
  
  late NotificationProvider _notificationProvider;
  late TransactionProvider _transactionProvider;
  StreamSubscription? _notificationSubscription;
  
  NotificationService._();
  
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }
  
  void initialize({
    required NotificationProvider notificationProvider,
    required TransactionProvider transactionProvider,
  }) {
    _notificationProvider = notificationProvider;
    _transactionProvider = transactionProvider;
    
    // Set up method call handler for receiving notifications from native
    platform.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final String jsonData = call.arguments as String;
        _processNotification(jsonData);
        break;
      default:
        print('Unknown method: ${call.method}');
    }
  }
  
  void _processNotification(String jsonData) {
    try {
      final data = jsonDecode(jsonData);
      
      // Extract sender and message
      final sender = data['sender']?.toString().trim() ?? '';
      final message = data['message']?.toString().trim() ?? '';
      
      // Filter out empty notifications
      if (sender.isEmpty && message.isEmpty) {
        print('Ignoring empty notification');
        return;
      }
      
      // Create notification model
      final notification = NotificationModel(
        packageName: data['packageName'] ?? 'com.kakao.talk',
        sender: sender,
        message: message,
        parsedData: data['parsedData'],
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      // Add to notification provider
      _notificationProvider.addNotification(notification);
      
      // If it's a financial transaction, add to transaction provider
      if (data['parsedData'] != null) {
        final parsedData = data['parsedData'] as Map<String, dynamic>;
        if (parsedData['type'] != 'unknown') {
          _transactionProvider.addTransactionFromNotification(parsedData);
        }
      }
      
    } catch (e) {
      print('Error processing notification: $e');
    }
  }
  
  // Check if notification permission is granted
  Future<bool> checkNotificationPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkNotificationPermission');
      return result;
    } on PlatformException catch (e) {
      print('Failed to check permission: ${e.message}');
      return false;
    }
  }
  
  // Request notification permission
  Future<void> requestNotificationPermission() async {
    try {
      await platform.invokeMethod('requestNotificationPermission');
    } on PlatformException catch (e) {
      print('Failed to request permission: ${e.message}');
    }
  }
  
  // Check if service is running
  Future<bool> isServiceRunning() async {
    try {
      final bool result = await platform.invokeMethod('isServiceRunning');
      return result;
    } on PlatformException catch (e) {
      print('Failed to check service status: ${e.message}');
      return false;
    }
  }
  
  void dispose() {
    _notificationSubscription?.cancel();
  }
}