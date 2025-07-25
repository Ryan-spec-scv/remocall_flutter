import 'dart:convert';
import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'https://api.remocall.com'; // 실제 API URL로 변경 필요
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

  // 로그인
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      return {
        'success': true,
        'access_token': response.data['access_token'],
        'refresh_token': response.data['refresh_token'],
        'user': response.data['user'],
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // 회원가입
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
        },
      );
      return {
        'success': true,
        'message': response.data['message'],
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // 사용자 정보 조회
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    try {
      final response = await _dio.get(
        '/user/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return {
        'success': true,
        'user': response.data,
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  // 거래 내역 조회
  Future<Map<String, dynamic>> getTransactions({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return {
        'success': true,
        'transactions': response.data['transactions'],
        'total': response.data['total'],
        'page': response.data['page'],
        'totalPages': response.data['total_pages'],
      };
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
        }
      }
    }

    return {
      'success': false,
      'message': message,
    };
  }
}