// macOS version of NotificationService
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  Future<void> initialize() async {
    // No-op for macOS
  }
  
  void dispose() {
    // No-op for macOS
  }
}
