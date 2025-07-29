import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:remocall_flutter/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  bool _isRefreshing = false;
  final _refreshCompleter = <Function>[];

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectionTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 요청 인터셉터 - 토큰 추가
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 토큰 불필요한 엔드포인트
        if (options.path.contains('/auth/login') || 
            options.path.contains('/auth/refresh') ||
            options.data is Map && options.data['skipAuth'] == true) {
          return handler.next(options);
        }
        
        // 토큰 로드
        // 이미 Authorization 헤더가 있으면 그대로 사용
        if (options.headers['Authorization'] != null) {
          return handler.next(options);
        }
        
        if (_accessToken == null) {
          await _loadTokens();
        }
        
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && 
            !error.requestOptions.path.contains('/auth/refresh')) {
          // 토큰 갱신 시도
          if (await _refreshTokenIfNeeded()) {
            // 토큰 갱신 성공 - 원래 요청 재시도
            try {
              final response = await _dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: Options(
                  method: error.requestOptions.method,
                  headers: {
                    ...error.requestOptions.headers,
                    'Authorization': 'Bearer $_accessToken',
                  },
                ),
              );
              return handler.resolve(response);
            } catch (e) {
              return handler.reject(error);
            }
          }
        }
        return handler.next(error);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: true,
      error: true,
      logPrint: (message) {
        print('[Dio] $message');
      },
    ));
    
    // 토큰 초기 로드
    _loadTokens();
  }
  
  // SharedPreferences에서 토큰 로드
  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('flutter.access_token');
    _refreshToken = prefs.getString('flutter.refresh_token');
  }
  
  // 토큰 저장
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flutter.access_token', accessToken);
    await prefs.setString('flutter.refresh_token', refreshToken);
  }
  
  // 토큰 갱신
  Future<bool> _refreshTokenIfNeeded() async {
    if (_isRefreshing) {
      // 이미 갱신 중이면 대기
      final completer = () async {};
      _refreshCompleter.add(completer);
      await completer();
      return _accessToken != null;
    }
    
    _isRefreshing = true;
    
    try {
      if (_refreshToken == null) {
        await _loadTokens();
        if (_refreshToken == null) {
          print('[API] No refresh token available');
          return false;
        }
      }
      
      print('[API] Attempting token refresh...');
      final response = await _dio.post(
        '/api/shop/auth/refresh',
        data: {'refresh_token': _refreshToken},
      );
      
      if (response.data['success'] == true) {
        final newAccessToken = response.data['data']['access_token'];
        final newRefreshToken = response.data['data']['refresh_token'];
        
        await _saveTokens(newAccessToken, newRefreshToken);
        print('[API] Token refresh successful');
        
        // 대기 중인 요청들 처리
        for (final completer in _refreshCompleter) {
          completer();
        }
        _refreshCompleter.clear();
        
        return true;
      } else {
        print('[API] Token refresh failed: ${response.data['message']}');
        return false;
      }
    } catch (e) {
      print('[API] Token refresh error: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // 매장 로그인 (PIN 방식)
  Future<Map<String, dynamic>> shopLogin(String shopCode, String pin) async {
    try {
      print('[API Service] Login attempt:');
      print('  - Base URL: ${_dio.options.baseUrl}');
      print('  - Shop Code: $shopCode');
      print('  - PIN: $pin');
      print('  - PIN length: ${pin.length}');
      
      final response = await _dio.post(
        '/api/shop/auth/login',
        data: {
          'shop_code': shopCode,
          'pin': pin,
          'skipAuth': true,
        },
      );
      
      print('[API Service] Login response: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('[API Service] Login error: ${e.response?.data}');
      return _handleError(e);
    }
  }

  // 토큰 갱신
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/api/shop/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  // 초기 데이터 조회 (매장프로필 + 잔액 + 대시보드 통합)
  Future<Map<String, dynamic>> getInitialData(String token) async {
    try {
      final response = await _dio.get(
        '/api/shop/app/initial',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  // 실시간 데이터 조회 (대시보드 주기적 갱신용)
  Future<Map<String, dynamic>> getRealTimeData(String token) async {
    try {
      final response = await _dio.get(
        '/api/shop/app/realtime',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  

  // 거래 내역 조회
  Future<Map<String, dynamic>> getTransactions({
    required String token,
    String? status,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        'status': status ?? 'completed',
      };
      
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      
      print('[API Service] getTransactions queryParams: $queryParams');
      
      final response = await _dio.get(
        '/api/shop/data/transactions',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }


  // 거래 상세 조회
  Future<Map<String, dynamic>> getTransactionDetail({
    required String token,
    required int transactionId,
  }) async {
    try {
      final response = await _dio.get(
        '/api/shop/data/transactions/$transactionId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  // 미매칭 입금 통계 조회
  Future<Map<String, dynamic>> getUnmatchedDepositsStats({
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        '/api/shop/data/deposits/unmatched/stats',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  // 미매칭 입금 목록 조회
  Future<Map<String, dynamic>> getUnmatchedDeposits({
    required String token,
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      
      print('[API] getUnmatchedDeposits - Request URL: ${_dio.options.baseUrl}/api/shop/data/deposits/unmatched');
      print('[API] getUnmatchedDeposits - Query params: $queryParams');
      print('[API] getUnmatchedDeposits - Token: ${token.substring(0, 10)}...');
      
      final response = await _dio.get(
        '/api/shop/data/deposits/unmatched',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      print('[API] getUnmatchedDeposits - Response status: ${response.statusCode}');
      print('[API] getUnmatchedDeposits - Response headers: ${response.headers}');
      print('[API] getUnmatchedDeposits - Response data type: ${response.data.runtimeType}');
      print('[API] getUnmatchedDeposits - Raw response data: ${response.data}');
      
      // Ensure we always return a Map<String, dynamic>
      if (response.data is Map<String, dynamic>) {
        return response.data;
      } else {
        print('[API] getUnmatchedDeposits - WARNING: Response data is not a Map, wrapping it');
        return {
          'success': true,
          'data': response.data,
        };
      }
    } on DioException catch (e) {
      print('[API] getUnmatchedDeposits - DioException: ${e.type}');
      print('[API] getUnmatchedDeposits - Error response: ${e.response?.data}');
      print('[API] getUnmatchedDeposits - Error status code: ${e.response?.statusCode}');
      return _handleError(e);
    } catch (e) {
      print('[API] getUnmatchedDeposits - Unexpected error: $e');
      return {
        'success': false,
        'message': 'Unexpected error: $e',
      };
    }
  }
  
  // 유저 확인 완료
  Future<Map<String, dynamic>> confirmUserDeposit({
    required String token,
    required int depositId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/shop/data/deposits/$depositId/confirm-user',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  // 카카오페이 알림 전송
  Future<Map<String, dynamic>> sendKakaoNotification({
    required Map<String, dynamic> notificationData,
    String? token,
  }) async {
    try {
      // BaseURL을 AppConfig에서 가져옴
      final tempDio = Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));
      
      tempDio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ));
      
      final response = await tempDio.post(
        '/api/kakao-deposits/webhook',
        data: notificationData,
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // 에러 처리
  Map<String, dynamic> _handleError(DioException e) {
    String message = '알 수 없는 오류가 발생했습니다';
    
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = '연결 시간이 초과되었습니다';
    } else if (e.type == DioExceptionType.connectionError) {
      message = '네트워크 연결을 확인해주세요';
    } else if (e.response != null) {
      // 서버 에러 응답 처리
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;
      
      if (data is Map && data.containsKey('message')) {
        message = data['message'];
      } else {
        switch (statusCode) {
          case 400:
            message = '잘못된 요청입니다';
            break;
          case 401:
            message = '인증이 필요합니다';
            break;
          case 403:
            message = '권한이 없습니다';
            break;
          case 404:
            message = '요청한 리소스를 찾을 수 없습니다';
            break;
          case 500:
            message = '서버 오류가 발생했습니다';
            break;
          default:
            message = '오류가 발생했습니다 (코드: $statusCode)';
        }
      }
    }
    
    print('[API] _handleError - Error type: ${e.type}');
    print('[API] _handleError - Error message: $message');
    
    return {
      'success': false,
      'message': message,
      'data': null,  // Ensure data field exists for consistency
    };
  }
}