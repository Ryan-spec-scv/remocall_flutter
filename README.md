# 리모콜 (Remocall) - Flutter Version

카카오톡 알림을 파싱하여 거래내역을 자동으로 관리하는 Flutter 기반 크로스플랫폼 앱입니다.

## 주요 기능

- 🔔 **카카오톡 알림 파싱**: 금융 거래 관련 카카오톡 알림을 자동으로 파싱
- 💰 **거래내역 관리**: 수입/지출 자동 분류 및 통계
- 🔄 **실시간 동기화**: WebSocket을 통한 실시간 서버 동기화
- 📱 **크로스플랫폼**: iOS와 Android 동시 지원
- 🌐 **오프라인 지원**: 네트워크 없이도 동작, 연결 시 자동 동기화

## 기술 스택

- **Frontend**: Flutter 3.x, Dart
- **상태관리**: Provider
- **네트워크**: Dio (REST API), WebSocket
- **로컬 DB**: Sqflite
- **백그라운드**: WorkManager
- **UI/UX**: Material Design 3, Custom Animations

## 프로젝트 구조

```
remocall_flutter/
├── lib/
│   ├── main.dart                 # 앱 진입점
│   ├── models/                   # 데이터 모델
│   │   ├── user.dart
│   │   ├── transaction_model.dart
│   │   └── notification_model.dart
│   ├── providers/                # 상태 관리
│   │   ├── auth_provider.dart
│   │   ├── transaction_provider.dart
│   │   └── notification_provider.dart
│   ├── screens/                  # UI 화면
│   │   ├── auth/                 # 인증 관련
│   │   ├── home/                 # 홈 화면
│   │   ├── transactions/         # 거래내역
│   │   ├── notifications/        # 알림 설정
│   │   └── settings/             # 설정
│   ├── services/                 # 비즈니스 로직
│   │   ├── api_service.dart      # REST API
│   │   ├── websocket_service.dart # WebSocket
│   │   ├── database_service.dart  # 로컬 DB
│   │   └── notification_service.dart # 알림 처리
│   ├── utils/                    # 유틸리티
│   │   └── theme.dart            # 테마 설정
│   └── widgets/                  # 재사용 가능한 위젯
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       └── transaction_card.dart
├── android/                      # Android 네이티브 코드
│   └── app/src/main/kotlin/      # NotificationListener
├── ios/                          # iOS 네이티브 코드
└── pubspec.yaml                  # 의존성 관리
```

## 설치 및 실행

### 사전 요구사항

- Flutter SDK 3.0 이상
- Dart SDK 3.0 이상
- Android Studio / Xcode
- 실제 디바이스 또는 에뮬레이터

### 설치 방법

```bash
# Flutter 설치 확인
flutter doctor

# 의존성 설치
flutter pub get

# iOS 의존성 설치 (Mac에서만)
cd ios && pod install && cd ..

# 실행
flutter run
```

## 플랫폼별 특징

### Android
- NotificationListenerService를 통한 카카오톡 알림 접근
- 백그라운드에서도 알림 파싱 가능
- WorkManager를 통한 주기적 동기화

### iOS
- 시스템 제약으로 직접적인 알림 접근 불가
- 대안: 
  - 사용자가 수동으로 스크린샷 업로드
  - 카카오톡 API 연동 (OAuth)
  - 푸시 알림 서버 경유

## 주요 화면

1. **로그인/회원가입**: 이메일 기반 인증
2. **홈**: 잔액 요약, 최근 거래내역
3. **거래내역**: 전체 거래 목록, 필터링
4. **알림 설정**: 웹훅 URL 설정, 동기화 상태
5. **설정**: 프로필, 테마, 로그아웃

## 개발 현황

### 완료된 기능
- ✅ 프로젝트 구조 설정
- ✅ 인증 시스템 (로그인/회원가입)
- ✅ 상태 관리 (Provider)
- ✅ UI/UX 디자인
- ✅ API 통신 모듈

### 진행 중
- 🔄 WebSocket 실시간 통신
- 🔄 로컬 데이터베이스 구현
- 🔄 Android 네이티브 알림 리스너

### 예정
- ⏳ iOS 대체 방안 구현
- ⏳ 백그라운드 동기화
- ⏳ 테스트 및 최적화

## 라이센스

이 프로젝트는 비공개 프로젝트입니다.