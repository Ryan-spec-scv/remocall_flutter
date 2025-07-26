#!/bin/bash

# 빌드 스크립트 - 개발/프로덕션 버전 모두 빌드

echo "🚀 SnapPay 빌드 스크립트 시작..."

# Flutter 경로 설정
FLUTTER_PATH="/Users/gwang/flutter/bin/flutter"

# 빌드 디렉토리 정리
echo "📁 기존 빌드 파일 정리 중..."
rm -rf build/app/outputs/flutter-apk/*.apk

# 프로덕션 버전 빌드
echo ""
echo "🏭 프로덕션 버전 빌드 중..."
$FLUTTER_PATH build apk --release --dart-define=IS_PRODUCTION=true

# 프로덕션 APK 이름 변경
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    mv build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/snappay-production.apk
    echo "✅ 프로덕션 버전 빌드 완료: snappay-production.apk"
else
    echo "❌ 프로덕션 버전 빌드 실패"
fi

# 개발 버전 빌드
echo ""
echo "🔧 개발 버전 빌드 중..."
$FLUTTER_PATH build apk --release --dart-define=IS_PRODUCTION=false

# 개발 APK 이름 변경
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    mv build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/snappay-development.apk
    echo "✅ 개발 버전 빌드 완료: snappay-development.apk"
else
    echo "❌ 개발 버전 빌드 실패"
fi

# 빌드 결과 표시
echo ""
echo "📦 빌드 완료!"
echo "빌드된 APK 파일:"
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null

# 설치 안내
echo ""
echo "📱 설치 방법:"
echo "프로덕션: adb install -r build/app/outputs/flutter-apk/snappay-production.apk"
echo "개발: adb install -r build/app/outputs/flutter-apk/snappay-development.apk"