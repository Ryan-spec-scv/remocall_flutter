import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/notification_model.dart';
import 'package:remocall_flutter/services/database_service.dart';
import 'package:remocall_flutter/services/websocket_service.dart';

class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  final DatabaseService _databaseService = DatabaseService();
  final WebSocketService _webSocketService = WebSocketService();
  
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  NotificationProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _databaseService.initialize();
    await loadNotifications();
    
    _webSocketService.connectionStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });
    
    _webSocketService.messageStream.listen((message) {
      // Handle incoming WebSocket messages
      print('Received WebSocket message: $message');
    });
  }

  Future<void> loadNotifications() async {
    _setLoading(true);
    try {
      final notifications = await _databaseService.getNotifications();
      _notifications.clear();
      _notifications.addAll(notifications);
      _error = null;
    } catch (e) {
      _error = '알림을 불러오는데 실패했습니다';
      print('Error loading notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addNotification(NotificationModel notification) async {
    try {
      // Save to local database
      final id = await _databaseService.insertNotification(notification);
      final savedNotification = notification.copyWith(id: id);
      _notifications.insert(0, savedNotification);
      
      // Send via WebSocket if connected
      if (_isConnected) {
        _webSocketService.sendNotification(savedNotification);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  Future<void> syncUnsentNotifications() async {
    if (!_isConnected) return;
    
    try {
      final unsentNotifications = await _databaseService.getUnsentNotifications();
      
      for (final notification in unsentNotifications) {
        _webSocketService.sendNotification(notification);
        await _databaseService.markNotificationAsSent(notification.id!);
      }
      
      await loadNotifications();
    } catch (e) {
      print('Error syncing notifications: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      await _databaseService.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> connectWebSocket(String url, String? token) async {
    await _webSocketService.connect(url, token);
    
    // Sync unsent notifications when connected
    if (_isConnected) {
      await syncUnsentNotifications();
    }
  }

  void disconnectWebSocket() {
    _webSocketService.disconnect();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }
}