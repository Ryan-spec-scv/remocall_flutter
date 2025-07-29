# Google Drive API 설정 가이드

이 문서는 SnapPay 앱의 로그를 Google Drive에 업로드하기 위한 설정 가이드입니다.

## 1. Google Cloud Console 설정

### 1.1 프로젝트 생성 또는 선택
1. [Google Cloud Console](https://console.cloud.google.com/)에 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택

### 1.2 Google Drive API 활성화
1. API 및 서비스 > 라이브러리로 이동
2. "Google Drive API" 검색
3. "사용 설정" 클릭

### 1.3 서비스 계정 생성
1. API 및 서비스 > 사용자 인증 정보로 이동
2. "사용자 인증 정보 만들기" > "서비스 계정" 선택
3. 서비스 계정 이름 입력 (예: "snappay-log-uploader")
4. 역할: "기본" > "편집자" 선택
5. 완료 클릭

### 1.4 서비스 계정 키 생성
1. 생성된 서비스 계정 클릭
2. "키" 탭으로 이동
3. "키 추가" > "새 키 만들기" > "JSON" 선택
4. 다운로드된 JSON 파일을 안전하게 보관

## 2. Google Drive 폴더 설정

### 2.1 로그 저장용 루트 폴더 생성
1. Google Drive에서 "SnapPay Logs" 폴더 생성
2. 폴더 우클릭 > "공유" 클릭
3. 서비스 계정 이메일 추가 (JSON 파일의 `client_email`)
4. 권한: "편집자"로 설정

### 2.2 매장 코드별 하위 폴더 구조
```
SnapPay Logs/
├── 0101/
├── 0102/
├── 0103/
└── ...
```

## 3. Android 앱 설정

### 3.1 Google Drive API 라이브러리 추가
`android/app/build.gradle.kts`에 다음 의존성 추가:

```kotlin
dependencies {
    implementation("com.google.api-client:google-api-client-android:2.0.0")
    implementation("com.google.apis:google-api-services-drive:v3-rev197-1.25.0")
    implementation("com.google.auth:google-auth-library-oauth2-http:1.19.0")
}
```

### 3.2 권한 추가
`android/app/src/main/AndroidManifest.xml`에 추가:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 3.3 서비스 계정 키 파일 추가
1. 다운로드한 JSON 키 파일을 `android/app/src/main/assets/` 폴더에 복사
2. 파일명을 `google_drive_service_account.json`으로 변경

## 4. 구현 변경사항

### 4.1 현재 구현 (서버 업로드)
현재 `LogManager.kt`는 서버 API 엔드포인트로 로그를 업로드합니다:
- Production: `https://admin-api.snappay.online/api/app/logs/upload`
- Development: `https://kakaopay-admin-api.flexteam.kr/api/app/logs/upload`

### 4.2 Google Drive 직접 업로드로 변경
서버를 거치지 않고 Google Drive에 직접 업로드하려면:

1. Google Drive API 클라이언트 초기화
2. 서비스 계정 인증
3. 파일 업로드 구현
4. 폴더 생성 및 관리

## 5. 보안 고려사항

### 5.1 서비스 계정 키 보호
- 서비스 계정 키 파일을 앱에 포함시키는 것은 보안 위험이 있습니다
- 대안:
  1. 서버 프록시 사용 (현재 구현)
  2. Firebase Functions 또는 Cloud Functions 사용
  3. 키 파일을 암호화하여 저장

### 5.2 권한 최소화
- 서비스 계정에는 필요한 최소한의 권한만 부여
- 특정 폴더에만 쓰기 권한 부여

## 6. 서버 기반 업로드 (권장)

현재 구현된 서버 기반 업로드 방식의 장점:
1. 서비스 계정 키가 서버에만 있어 보안성 높음
2. 업로드 로직을 서버에서 중앙 관리
3. 추가 인증/검증 로직 구현 가능
4. 로그 데이터 전처리 가능

서버 측에서 Google Drive 업로드를 구현하는 방법:
1. 서버에 Google Drive API 라이브러리 설치
2. 서비스 계정 키를 서버에 안전하게 저장
3. 클라이언트로부터 받은 로그를 Google Drive에 업로드
4. 매장 코드별 폴더 자동 생성 및 관리

## 7. 결론

보안과 관리 측면에서 현재의 서버 기반 업로드 방식을 유지하는 것이 권장됩니다. 
서버에서 Google Drive로 업로드하는 기능을 구현하면, 클라이언트 앱은 현재 코드를 그대로 사용할 수 있습니다.