# SnapPay 빌드 가이드

## GitHub Actions를 통한 자동 빌드

### 1. 수동 빌드 실행
1. GitHub 저장소 페이지로 이동
2. Actions 탭 클릭
3. "Build Release" workflow 선택
4. "Run workflow" 버튼 클릭
5. 빌드할 플랫폼 선택 (Android, Windows 또는 둘 다)
6. "Run workflow" 실행

### 2. 태그를 통한 자동 빌드
```bash
# 새 버전 태그 생성 및 푸시
git tag v1.0.26
git push origin v1.0.26
```
태그를 푸시하면 자동으로 Android와 Windows 빌드가 시작되고 GitHub Release가 생성됩니다.

### 3. 빌드 결과 다운로드
- **Actions 탭에서**: 완료된 workflow → Artifacts에서 다운로드
- **Releases 페이지에서**: 자동 생성된 릴리스에서 다운로드

## 로컬 빌드

### Android (macOS/Windows/Linux)
```bash
flutter build apk --release
# 결과: build/app/outputs/flutter-apk/app-release.apk
```

### Windows (Windows에서만 가능)
```bash
flutter build windows --release
# 결과: build/windows/x64/runner/Release/
```

## 플랫폼별 기능

### Android
- ✅ 카카오페이 알림 파싱
- ✅ 자동 거래 기록
- ✅ 실시간 데이터 조회
- ✅ 업데이트 기능

### Windows
- ✅ 데이터 조회
- ✅ 거래 내역 확인
- ✅ 통계 확인
- ❌ 알림 파싱 (Android 전용)
- ❌ 자동 업데이트 (Android 전용)

## 배포 방법

### Android
1. APK 파일을 서버에 업로드
2. 사용자에게 다운로드 링크 제공
3. 설치 시 "알 수 없는 출처" 허용 필요

### Windows
1. Release 폴더 전체를 ZIP으로 압축
2. 사용자에게 배포
3. 압축 해제 후 exe 파일 실행