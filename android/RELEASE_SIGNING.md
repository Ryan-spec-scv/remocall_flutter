# Android Release 서명 설정 가이드

## 1. 키스토어 생성

```bash
keytool -genkey -v -keystore snappay-release.jks -alias snappay -keyalg RSA -keysize 2048 -validity 10000
```

입력 항목:
- 키스토어 비밀번호: 안전한 비밀번호 설정
- 키 비밀번호: 동일하거나 다른 비밀번호 설정
- 이름: 회사명 또는 개인명
- 조직 단위: 부서명 (선택사항)
- 조직: 회사명
- 도시: 도시명
- 시/도: 시/도
- 국가 코드: KR

## 2. key.properties 파일 생성

`android/key.properties` 파일을 생성하고 다음 내용 입력:

```properties
storePassword=키스토어_비밀번호
keyPassword=키_비밀번호
keyAlias=snappay
storeFile=./snappay-release.jks
```

## 3. 파일 위치

- `snappay-release.jks`: `android/` 디렉토리에 저장
- `key.properties`: `android/` 디렉토리에 저장

## 4. 보안 주의사항

⚠️ **중요**: 다음 파일들은 절대 Git에 커밋하지 마세요!
- `key.properties`
- `*.jks`
- `*.keystore`

이미 `.gitignore`에 추가되어 있지만, 실수로 커밋하지 않도록 주의하세요.

## 5. 빌드 확인

```bash
# Release APK 빌드
flutter build apk --release

# 또는 빌드 스크립트 사용
./build_all.sh
```

## 6. 키스토어 백업

키스토어 파일과 비밀번호는 안전한 곳에 백업하세요. 
분실 시 앱 업데이트가 불가능합니다!