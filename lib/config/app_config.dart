class AppConfig {
  // API 설정
  static const String apiBaseUrl = 'https://admin-api.snappay.online';
  static const String apiBaseUrlDev = 'https://kakaopay-admin-api.flexteam.kr'; // 개발용
  
  // 현재 환경 (true: 프로덕션, false: 개발)
  // 빌드 시 --dart-define=IS_PRODUCTION=true/false로 설정
  static const bool isProduction = bool.fromEnvironment('IS_PRODUCTION', defaultValue: true);
  
  // 실제 사용할 API URL
  static String get baseUrl => isProduction ? apiBaseUrl : apiBaseUrlDev;
  
  // 앱 정보
  static const String appName = '리모콜';
  static const String appVersion = '1.0.39';
  
  // 타임아웃 설정
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // 자동 갱신 주기
  static const Duration refreshInterval = Duration(seconds: 10);
  static const Duration notificationCheckInterval = Duration(seconds: 5);
  
  // 업데이트 서버 URL
  static const String updateServerUrl = 'https://admin-api.snappay.online';
  static const String updateServerUrlDev = 'https://kakaopay-admin-api.flexteam.kr';
  
  // 실제 사용할 업데이트 서버 URL
  static String get updateUrl => isProduction ? updateServerUrl : updateServerUrlDev;
}