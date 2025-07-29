#!/bin/bash

echo "🍎 Starting clean macOS build for SnapPay..."

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Flutter 및 CocoaPods 경로 설정
export PATH="/Users/gwang/flutter/bin:$PATH"
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"

# 1. 기존 빌드 정리
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf build
rm -rf macos
flutter clean

# 2. macOS 프로젝트 생성
echo -e "${YELLOW}🔧 Creating macOS project...${NC}"
flutter config --enable-macos-desktop
flutter create --platforms=macos .

# 3. UpdateService 스텁 생성 (macOS에서는 필요없지만 컴파일 오류 방지용)
echo -e "${YELLOW}📝 Creating stub files for compilation...${NC}"
mkdir -p lib/services

cat > lib/services/update_service.dart << 'EOF'
// Stub for macOS build
class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final bool isForceUpdate;
  
  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.isForceUpdate,
  });
}

class UpdateService {
  Future<void> checkForUpdate({
    required Function(UpdateInfo) onUpdateAvailable,
    required Function() onLatestVersion,
    required Function(String) onError,
  }) async {
    // No-op for macOS
  }
  
  Future<void> downloadAndInstallApk(UpdateInfo updateInfo) async {
    // No-op for macOS
  }
}
EOF

# 4. NotificationService 수정
cat > lib/services/notification_service_macos.dart << 'EOF'
// macOS version of NotificationService
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  Future<void> initialize() async {
    // No-op for macOS
  }
  
  void dispose() {
    // No-op for macOS
  }
}
EOF

# 5. ThemeProvider에 loadThemePreference 메서드 추가
echo -e "${YELLOW}🎨 Updating ThemeProvider...${NC}"
if ! grep -q "loadThemePreference" lib/providers/theme_provider.dart; then
  sed -i '' '/class ThemeProvider extends ChangeNotifier {/a\
\
  Future<void> loadThemePreference() async {\
    final prefs = await SharedPreferences.getInstance();\
    final isDark = prefs.getBool('\''isDarkMode'\'') ?? false;\
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;\
    notifyListeners();\
  }\
' lib/providers/theme_provider.dart
fi

# 6. main.dart 수정하여 notification_service_macos 사용
sed -i '' 's|import .*/notification_service.dart.*;|import '\''package:remocall_flutter/services/notification_service_macos.dart'\'';|g' lib/main.dart

# 7. 앱 이름 변경
echo -e "${YELLOW}✏️  Updating app name to SnapPay...${NC}"
/usr/libexec/PlistBuddy -c "Set :CFBundleName SnapPay" macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string SnapPay" macos/Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName SnapPay" macos/Runner/Info.plist

sed -i '' 's/PRODUCT_NAME = remocall_flutter/PRODUCT_NAME = SnapPay/g' macos/Runner/Configs/AppInfo.xcconfig
sed -i '' 's/com.example.remocallFlutter/com.snappay.app/g' macos/Runner/Configs/AppInfo.xcconfig

# 8. 의존성 설치
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
flutter pub get

# 9. macOS 앱 빌드
echo -e "${YELLOW}🏗️  Building macOS app...${NC}"
flutter build macos --release

# 10. 빌드 결과 확인
if [ -d "build/macos/Build/Products/Release/SnapPay.app" ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${GREEN}📍 App location: build/macos/Build/Products/Release/SnapPay.app${NC}"
    
    # 앱 정보 표시
    echo -e "\n${YELLOW}App Info:${NC}"
    echo "Bundle ID: $(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" build/macos/Build/Products/Release/SnapPay.app/Contents/Info.plist)"
    echo "Version: $(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/macos/Build/Products/Release/SnapPay.app/Contents/Info.plist)"
    
    # DMG 생성 옵션
    echo -e "\n${YELLOW}Would you like to create a DMG installer? (y/n)${NC}"
    read -r CREATE_DMG
    
    if [[ $CREATE_DMG =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}📀 Creating DMG...${NC}"
        rm -rf dmg_temp
        mkdir -p dmg_temp
        cp -R build/macos/Build/Products/Release/SnapPay.app dmg_temp/
        
        # 심볼릭 링크로 Applications 폴더 추가
        ln -s /Applications dmg_temp/Applications
        
        # DMG 생성
        hdiutil create -volname "SnapPay" -srcfolder dmg_temp -ov -format UDZO SnapPay.dmg
        rm -rf dmg_temp
        echo -e "${GREEN}✅ DMG created: SnapPay.dmg${NC}"
    fi
    
    # 앱 실행 옵션
    echo -e "\n${YELLOW}Would you like to run the app? (y/n)${NC}"
    read -r RUN_APP
    
    if [[ $RUN_APP =~ ^[Yy]$ ]]; then
        open build/macos/Build/Products/Release/SnapPay.app
    fi
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo -e "${RED}Check the error messages above for details.${NC}"
    exit 1
fi