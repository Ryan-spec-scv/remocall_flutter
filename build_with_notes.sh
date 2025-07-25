#!/bin/bash

# 릴리즈 노트 입력받기
echo "Enter release notes (press Ctrl+D when done):"
RELEASE_NOTES=$(cat)

# 버전 정보 읽기
VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //')

# 릴리즈 정보 JSON 생성
cat > release_info.json <<EOF
{
  "version": "$VERSION",
  "buildDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "releaseNotes": "$RELEASE_NOTES",
  "changes": []
}
EOF

# assets 폴더에 복사
cp release_info.json assets/

# Flutter 빌드
flutter build apk --release

# 빌드된 APK와 함께 릴리즈 정보도 서버에 업로드할 수 있음
echo "Build completed with release notes!"