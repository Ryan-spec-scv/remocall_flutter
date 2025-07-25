import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/user.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _accessToken != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get accessToken => _accessToken;

  final ApiService _apiService = ApiService();

  Future<void> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      
      if (_accessToken != null) {
        // Verify token and get user info
        await getUserInfo();
      }
    } catch (e) {
      print('Error checking auth status: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;
    
    try {
      final response = await _apiService.login(email, password);
      
      if (response['success']) {
        _accessToken = response['access_token'];
        _refreshToken = response['refresh_token'];
        _currentUser = User.fromJson(response['user']);
        
        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        
        _setLoading(false);
        return true;
      } else {
        _error = response['message'] ?? '로그인에 실패했습니다';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = '네트워크 오류가 발생했습니다';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final response = await _apiService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      
      if (response['success']) {
        // Auto login after signup
        return await login(email, password);
      } else {
        _error = response['message'] ?? '회원가입에 실패했습니다';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = '네트워크 오류가 발생했습니다';
      _setLoading(false);
      return false;
    }
  }

  Future<void> getUserInfo() async {
    if (_accessToken == null) return;
    
    try {
      final response = await _apiService.getUserInfo(_accessToken!);
      if (response['success']) {
        _currentUser = User.fromJson(response['user']);
        notifyListeners();
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
    
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}