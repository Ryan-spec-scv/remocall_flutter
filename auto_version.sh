#!/bin/bash

# 현재 버전 읽기
current_version=$(grep "version:" pubspec.yaml | sed 's/version: //')
echo "Current version: $current_version"

# 버전과 빌드 번호 분리
version_name=$(echo $current_version | cut -d'+' -f1)
build_number=$(echo $current_version | cut -d'+' -f2)

# 빌드 번호 증가
new_build_number=$((build_number + 1))

# 패치 버전 증가 (선택사항)
IFS='.' read -r major minor patch <<< "$version_name"
new_patch=$((patch + 1))
new_version_name="$major.$minor.$new_patch"

# 새 버전 설정
new_version="$new_version_name+$new_build_number"
echo "New version: $new_version"

# pubspec.yaml 업데이트
sed -i '' "s/version: .*/version: $new_version/" pubspec.yaml

echo "Version updated to $new_version"

# 자동으로 빌드
flutter build apk --release