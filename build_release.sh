#!/bin/bash

# 버전 정보
VERSION="1.0.1"
CHANGELOG="DASHBOARD API fixed & Parsing Test Floating Button Hide"
DATE=$(date +%Y-%m-%d)

# release-info.json 생성
cat > release-info.json <<EOF
{
  "version_name": "$VERSION",
  "changelog": "$CHANGELOG",
  "version_date": "$DATE"
}
EOF

# Flutter 빌드
flutter build apk --release

# 빌드된 APK와 release-info.json을 같은 디렉토리에 복사
cp build/app/outputs/flutter-apk/app-release.apk .
echo "빌드 완료: app-release.apk, release-info.json"