#!/bin/bash

# 설치 스크립트

echo "📱 SnapPay 설치 스크립트"
echo ""
echo "설치할 버전을 선택하세요:"
echo "1) 프로덕션 버전"
echo "2) 개발 버전"
echo ""
read -p "선택 (1 또는 2): " choice

case $choice in
    1)
        echo "🏭 프로덕션 버전 설치 중..."
        if [ -f "build/app/outputs/flutter-apk/snappay-production.apk" ]; then
            adb install -r build/app/outputs/flutter-apk/snappay-production.apk
        else
            echo "❌ 프로덕션 APK 파일이 없습니다. 먼저 ./build_all.sh를 실행하세요."
        fi
        ;;
    2)
        echo "🔧 개발 버전 설치 중..."
        if [ -f "build/app/outputs/flutter-apk/snappay-development.apk" ]; then
            adb install -r build/app/outputs/flutter-apk/snappay-development.apk
        else
            echo "❌ 개발 APK 파일이 없습니다. 먼저 ./build_all.sh를 실행하세요."
        fi
        ;;
    *)
        echo "❌ 잘못된 선택입니다."
        exit 1
        ;;
esac