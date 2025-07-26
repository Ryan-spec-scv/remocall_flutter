#!/bin/bash

# 빠른 빌드 스크립트 - 단일 버전만 빌드

if [ "$1" = "dev" ]; then
    echo "🔧 개발 버전 빌드 및 설치..."
    /Users/gwang/flutter/bin/flutter build apk --release --dart-define=IS_PRODUCTION=false
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        adb install -r build/app/outputs/flutter-apk/app-release.apk
        echo "✅ 개발 버전 설치 완료"
    fi
elif [ "$1" = "prod" ]; then
    echo "🏭 프로덕션 버전 빌드 및 설치..."
    /Users/gwang/flutter/bin/flutter build apk --release --dart-define=IS_PRODUCTION=true
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        adb install -r build/app/outputs/flutter-apk/app-release.apk
        echo "✅ 프로덕션 버전 설치 완료"
    fi
else
    echo "사용법: ./quick_build.sh [dev|prod]"
    echo "  dev  - 개발 버전 빌드 및 설치"
    echo "  prod - 프로덕션 버전 빌드 및 설치"
fi