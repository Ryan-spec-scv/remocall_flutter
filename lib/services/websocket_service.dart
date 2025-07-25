import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:remocall_flutter/models/notification_model.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _connectionController = StreamController<bool>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  Timer? _reconnectTimer;
  String? _url;
  String? _token;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  
  bool get isConnected => _isConnected;

  Future<void> connect(String url, String? token) async {
    _url = url;
    _token = token;
    _reconnectAttempts = 0;
    
    await _connect();
  }

  Future<void> _connect() async {
    try {
      _channel?.sink.close();
      
      final wsUrl = Uri.parse(_url!);
      final headers = <String, String>{};
      
      if (_token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (data) {
          _isConnected = true;
          _connectionController.add(true);
          _reconnectAttempts = 0;
          
          try {
            final message = jsonDecode(data);
            _messageController.add(message);
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnection();
        },
      );
      
      // Send initial connection message
      _channel!.sink.add(jsonEncode({
        'type': 'connect',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _connectionController.add(false);
    _channel?.sink.close();
    _channel = null;
    
    // Attempt reconnection with exponential backoff
    if (_url != null && _reconnectAttempts < 5) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 2);
      print('Reconnecting in ${delay.inSeconds} seconds...');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        _connect();
      });
    }
  }

  void sendNotification(NotificationModel notification) {
    if (_channel != null && _isConnected) {
      try {
        final message = {
          'type': 'notification',
          'data': notification.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        print('Error sending notification: $e');
      }
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionController.add(false);
    _url = null;
    _token = null;
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _messageController.close();
  }
}