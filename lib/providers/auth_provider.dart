import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/user.dart';
import 'package:remocall_flutter/models/shop.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:remocall_flutter/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  Shop? _currentShop;
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;
  Timer? _tokenRefreshTimer;
  bool _isRefreshingToken = false;

  Shop? get currentShop => _currentShop;
  bool get isAuthenticated => _currentShop != null && _accessToken != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  final ApiService _apiService = ApiService();

  Future<void> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      
      if (_accessToken != null) {
        // Verify token and get user info
        await getShopProfile();
        
        // 토큰이 있으면 자동 갱신 타이머 시작
        _startTokenRefreshTimer();
      }
    } catch (e) {
      print('Error checking auth status: $e');
    }
  }

  Future<bool> loginWithPin(String shopCode, String pin) async {
    _setLoading(true);
    _error = null;
    
    try {
      final response = await _apiService.shopLogin(shopCode, pin);
      
      if (response['success']) {
        // 새로운 API 응답 형식에 맞춰 수정
        final data = response['data'];
        
        // 응답 구조 디버깅
        print('[AuthProvider] Login response data structure:');
        print('  - Has tokens key: ${data.containsKey('tokens')}');
        print('  - Tokens: ${data['tokens']}');
        
        _accessToken = data['tokens']['access_token'];
        _refreshToken = data['tokens']['refresh_token'];
        
        // Shop 객체 생성
        _currentShop = Shop.fromJson(data['shop']);
        
        // 토큰 및 매장 정보 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        // NotificationService\uc5d0\uc11c \uc0ac\uc6a9\ud558\ub294 \ud0a4\ub85c\ub3c4 \uc800\uc7a5
        await prefs.setString('flutter.access_token', _accessToken!);
        await prefs.setString('flutter.refresh_token', _refreshToken!);
        await prefs.setString('shop_code', shopCode);
        await prefs.setString('shop_name', _currentShop!.name);
        await prefs.setInt('shop_id', _currentShop!.id);
        await prefs.setBool('is_production', AppConfig.isProduction);
        
        _setLoading(false);
        
        // 로그인 성공 후 전체 프로필 정보 가져오기 (도메인 정보 포함)
        await getShopProfile();
        
        // 토큰 자동 갱신 타이머 시작
        _startTokenRefreshTimer();
        
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

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await _apiService.refreshToken(_refreshToken!);
      
      if (response['success']) {
        final data = response['data'];
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        
        // 새 토큰 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        // NotificationService\uc5d0\uc11c \uc0ac\uc6a9\ud558\ub294 \ud0a4\ub85c\ub3c4 \uc800\uc7a5
        await prefs.setString('flutter.access_token', _accessToken!);
        await prefs.setString('flutter.refresh_token', _refreshToken!);
        
        return true;
      }
    } catch (e) {
      print('Token refresh failed: $e');
    }
    
    return false;
  }

  // Legacy login methods 제거 - PIN 로그인만 사용

  // 매장은 관리자가 생성하므로 signUp 메서드 제거

  Future<void> getShopProfile() async {
    if (_accessToken == null) return;
    
    try {
      // 통합 API 사용
      final response = await _apiService.getInitialData(_accessToken!);
      if (response['success'] && response['data'] != null) {
        _currentShop = Shop.fromJson(response['data']['shop']);
        notifyListeners();
      }
    } catch (e) {
      print('Error getting shop profile: $e');
    }
  }

  void updateShopData(Map<String, dynamic> shopData) {
    _currentShop = Shop.fromJson(shopData);
    notifyListeners();
  }

  Future<void> logout() async {
    // 토큰 갱신 타이머 중지
    _stopTokenRefreshTimer();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('flutter.access_token');
    await prefs.remove('flutter.refresh_token');
    await prefs.remove('shop_code');
    await prefs.remove('shop_name');
    await prefs.remove('shop_id');
    
    _currentShop = null;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
    
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // 토큰 자동 갱신 타이머 시작
  void _startTokenRefreshTimer() {
    // 기존 타이머가 있으면 중지
    _stopTokenRefreshTimer();
    
    print('[AuthProvider] Starting token refresh timer - will refresh every hour');
    
    // 매시간 토큰 갱신 (3600초 = 1시간)
    _tokenRefreshTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      print('[AuthProvider] Token refresh timer triggered at ${DateTime.now()}');
      await _performTokenRefresh();
    });
  }

  // 토큰 갱신 타이머 중지
  void _stopTokenRefreshTimer() {
    if (_tokenRefreshTimer != null) {
      print('[AuthProvider] Stopping token refresh timer');
      _tokenRefreshTimer!.cancel();
      _tokenRefreshTimer = null;
    }
  }

  // 토큰 갱신 수행
  Future<void> _performTokenRefresh() async {
    // 이미 갱신 중이면 스킵
    if (_isRefreshingToken) {
      print('[AuthProvider] Token refresh already in progress, skipping...');
      return;
    }

    if (_refreshToken == null) {
      print('[AuthProvider] No refresh token available, skipping refresh');
      return;
    }

    _isRefreshingToken = true;
    print('[AuthProvider] Starting token refresh at ${DateTime.now()}');

    try {
      final success = await refreshAccessToken();
      
      if (success) {
        print('[AuthProvider] Token refresh successful at ${DateTime.now()}');
        
        // Android NotificationService에 토큰 갱신 알림
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_token_refresh', DateTime.now().toIso8601String());
        } catch (e) {
          print('[AuthProvider] Error updating token refresh timestamp: $e');
        }
      } else {
        print('[AuthProvider] Token refresh failed at ${DateTime.now()}');
        
        // 토큰 갱신 실패 시 재시도 (5분 후)
        Timer(const Duration(minutes: 5), () async {
          print('[AuthProvider] Retrying token refresh after failure');
          await _performTokenRefresh();
        });
      }
    } catch (e) {
      print('[AuthProvider] Exception during token refresh: $e');
    } finally {
      _isRefreshingToken = false;
    }
  }

  @override
  void dispose() {
    _stopTokenRefreshTimer();
    super.dispose();
  }
}