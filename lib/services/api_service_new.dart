import 'dart:convert';
import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.31.145:4000/api'; // 새 API 서버
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // 매장 로그인 (PIN 방식)
  Future<Map<String, dynamic>> shopLogin(String shopCode, String pin) async {
    try {
      final response = await _dio.post(
        '/shop/auth/login',
        data: {
          'shop_code': shopCode,
          'pin': pin,
        },
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // 토큰 갱신
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/shop/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }
  
  // 매장 프로필 조회
  Future<Map<String, dynamic>> getShopProfile(String token) async {
    try {
      final response = await _dio.get(
        '/shop/auth/profile',
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

  // 잔액 조회
  Future<Map<String, dynamic>> getBalance(String token) async {
    try {
      final response = await _dio.get(
        '/shop/data/balance',
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
      };
      
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      
      final response = await _dio.get(
        '/shop/data/transactions',
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

  // 대시보드 요약 조회
  Future<Map<String, dynamic>> getDashboard(String token) async {
    try {
      final response = await _dio.get(
        '/shop/data/dashboard',
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
        '/shop/data/transactions/$transactionId',
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
  
  // 알림 전송 (기존 기능 유지)
  Future<Map<String, dynamic>> sendNotification({
    required String token,
    required Map<String, dynamic> notificationData,
  }) async {
    try {
      final response = await _dio.post(
        '/notifications', // 새 API에서 제공하는지 확인 필요
        data: notificationData,
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
    
    return {
      'success': false,
      'message': message,
    };
  }
}