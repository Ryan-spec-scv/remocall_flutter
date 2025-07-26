import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/notification_model.dart';
import 'package:remocall_flutter/services/database_service.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();
  final Set<String> _recentNotificationHashes = {};
  
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _shopCode;
  bool _isSnapPayMode = false;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSnapPayMode => _isSnapPayMode;

  NotificationProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _databaseService.initialize();
    await loadNotifications();
    
    // Load access token and shop code
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _shopCode = prefs.getString('shop_code');
    _isSnapPayMode = prefs.getBool('is_snappay_mode') ?? false;
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
      print('=== ADD NOTIFICATION START ===');
      print('Sender: ${notification.sender}');
      print('Message: ${notification.message}');
      print('ParsedData: ${notification.parsedData}');
      
      // Create a hash to check for duplicates (based on sender, message, and exact timestamp)
      final timestamp = notification.receivedAt.millisecondsSinceEpoch;
      final hash = '${notification.sender}_${notification.message}_$timestamp';
      
      // Check if this is a duplicate
      if (_recentNotificationHashes.contains(hash)) {
        print('Duplicate notification detected, skipping: $hash');
        return;
      }
      
      // Add to recent hashes and clean old ones
      _recentNotificationHashes.add(hash);
      _cleanOldHashes();
      
      // Save to local database
      final id = await _databaseService.insertNotification(notification);
      final savedNotification = notification.copyWith(id: id);
      _notifications.insert(0, savedNotification);
      print('Notification saved to database with ID: $id');
      
      // Send to server if we have a token and it's a financial notification
      print('Access token: ${_accessToken != null ? "EXISTS" : "NULL"}');
      print('Has parsed data: ${notification.parsedData != null}');
      print('Parsed data type: ${notification.parsedData?['type']}');
      
      if (_accessToken != null && notification.parsedData != null && 
          notification.parsedData!['type'] != 'unknown') {
        print('Sending notification to server...');
        _sendNotificationToServer(savedNotification);
      } else {
        print('NOT sending to server - conditions not met');
        if (_accessToken == null) print('Reason: No access token');
        if (notification.parsedData == null) print('Reason: No parsed data');
        if (notification.parsedData?['type'] == 'unknown') print('Reason: Unknown type');
      }
      
      notifyListeners();
    } catch (e) {
      print('Error adding notification: $e');
    }
  }
  
  void _cleanOldHashes() {
    // Keep only the last 100 hashes to prevent memory issues
    if (_recentNotificationHashes.length > 100) {
      final toRemove = _recentNotificationHashes.length - 100;
      _recentNotificationHashes.toList()
        .take(toRemove)
        .forEach(_recentNotificationHashes.remove);
    }
  }

  // Removed WebSocket sync functionality as it's not needed

  Future<void> deleteNotification(int id) async {
    try {
      await _databaseService.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Send notification to server
  Future<void> _sendNotificationToServer(NotificationModel notification) async {
    try {
      print('=== SEND TO SERVER START ===');
      print('Notification ID: ${notification.id}');
      print('Message: ${notification.message}');
      print('ParsedData: ${notification.parsedData}');
      
      // 카카오페이 메시지 형식으로 전송 (message와 timestamp만 전송)
      final notificationData = {
        'message': notification.message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      print('Sending data: $notificationData');
      
      final response = await _apiService.sendKakaoNotification(
        notificationData: notificationData,
        token: _accessToken,
      );
      
      print('Server response: $response');
      
      if (response['success'] == true) {
        // Mark as sent to server in local database
        await _databaseService.markNotificationAsServerSent(notification.id!);
        
        // Update the notification in the list
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(
            isServerSent: true,
            serverSentAt: DateTime.now(),
          );
          notifyListeners();
        }
        
        print('✅ Notification sent to server successfully');
      } else {
        print('❌ Failed to send notification to server: ${response['message']}');
        // Update error message
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(
            errorMessage: response['message'] ?? 'Server error',
          );
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Error sending notification to server: $e');
      print('Error stack trace: ${e.toString()}');
      // Update error message
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] = notification.copyWith(
          errorMessage: 'Network error: ${e.toString()}',
        );
        notifyListeners();
      }
    }
    print('=== SEND TO SERVER END ===');
  }
  
  // Retry sending failed notifications
  Future<void> retrySendingFailedNotifications() async {
    if (_accessToken == null) return;
    
    try {
      final unsentNotifications = await _databaseService.getUnsentToServerNotifications();
      
      for (final notification in unsentNotifications) {
        await _sendNotificationToServer(notification);
      }
    } catch (e) {
      print('Error retrying notifications: $e');
    }
  }
  
  // Update access token and shop code when user logs in
  void updateAccessToken(String? token) {
    _accessToken = token;
    // Retry failed notifications when token is updated
    if (token != null) {
      retrySendingFailedNotifications();
    }
  }
  
  // Update shop code when user logs in
  void updateShopCode(String? shopCode) {
    _shopCode = shopCode;
  }
  
  // Toggle notification mode between KakaoPay and SnapPay
  Future<void> toggleNotificationMode() async {
    _isSnapPayMode = !_isSnapPayMode;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_snappay_mode', _isSnapPayMode);
    
    print('Notification mode changed to: ${_isSnapPayMode ? "SnapPay" : "KakaoPay"}');
    notifyListeners();
  }
  
  // Set notification mode explicitly
  Future<void> setNotificationMode(bool isSnapPayMode) async {
    _isSnapPayMode = isSnapPayMode;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_snappay_mode', _isSnapPayMode);
    
    print('Notification mode set to: ${_isSnapPayMode ? "SnapPay" : "KakaoPay"}');
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}