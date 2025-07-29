#!/bin/bash

echo "🍎 Starting macOS build for SnapPay..."

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Flutter 및 CocoaPods 경로 설정
export PATH="/Users/gwang/flutter/bin:$PATH"
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"

# Flutter 버전 확인
echo -e "${GREEN}Flutter version:${NC}"
flutter --version || { echo -e "${RED}❌ Flutter command not found!${NC}"; exit 1; }

# 1. 백업 원본 파일들
echo -e "${YELLOW}📦 Backing up original files...${NC}"
cp pubspec.yaml pubspec_backup.yaml
cp lib/main.dart lib/main_backup.dart

# 2. macOS용 pubspec 사용
echo -e "${YELLOW}📝 Using macOS-specific pubspec...${NC}"
cp pubspec_macos.yaml pubspec.yaml

# 3. macOS 프로젝트 생성
echo -e "${YELLOW}🔧 Creating macOS project files...${NC}"
rm -rf macos
flutter config --enable-macos-desktop
flutter create --platforms=macos .

# 4. 앱 이름 변경
echo -e "${YELLOW}✏️  Updating app name to SnapPay...${NC}"
# Info.plist 수정
/usr/libexec/PlistBuddy -c "Set :CFBundleName SnapPay" macos/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string SnapPay" macos/Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName SnapPay" macos/Runner/Info.plist

# AppInfo.xcconfig 수정
sed -i '' 's/PRODUCT_NAME = remocall_flutter/PRODUCT_NAME = SnapPay/g' macos/Runner/Configs/AppInfo.xcconfig
sed -i '' 's/com.example.remocallFlutter/com.snappay.app/g' macos/Runner/Configs/AppInfo.xcconfig

# 5. 문제가 있는 서비스 파일들 임시 이동
echo -e "${YELLOW}🗑️  Temporarily removing Android-specific files...${NC}"
mkdir -p temp_backup
mv lib/services/update_service.dart temp_backup/ 2>/dev/null || true
mv lib/services/apk_update_service.dart temp_backup/ 2>/dev/null || true

# 6. macOS용 main.dart 생성
echo -e "${YELLOW}📱 Creating macOS-compatible main.dart...${NC}"
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/providers/transaction_provider.dart';
import 'package:remocall_flutter/providers/theme_provider.dart';
import 'package:remocall_flutter/screens/splash_screen.dart';
import 'package:remocall_flutter/services/connectivity_service.dart';
import 'package:remocall_flutter/services/notification_service.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/widgets/app_initializer.dart';
import 'package:remocall_flutter/widgets/connectivity_wrapper.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remocall_flutter/config/app_config.dart';

// 빌드 시 설정된 프로덕션 모드를 SharedPreferences에 저장
Future<void> _saveProductionMode() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_production', AppConfig.isProduction);
  print('[SnapPay] Production mode saved: ${AppConfig.isProduction}');
}

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // macOS에서 디버그 메시지
    if (Platform.isMacOS) {
      print('[SnapPay] Starting macOS application...');
    }
    
    // 빌드 시 설정된 isProduction 값을 SharedPreferences에 저장
    await _saveProductionMode();

    // Initialize connectivity service
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();

    // Initialize theme provider
    final themeProvider = ThemeProvider();
    await themeProvider.loadThemePreference();

    // Notification service for connectivity monitoring
    final notificationService = NotificationService();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider.value(value: themeProvider),
          Provider.value(value: connectivityService),
          Provider.value(value: notificationService),
        ],
        child: const MyApp(),
      ),
    );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ConnectivityWrapper(
        child: AppInitializer(
          child: SplashScreen(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
EOF

# 7. 의존성 설치
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
flutter pub get

# 8. macOS 앱 빌드
echo -e "${YELLOW}🏗️  Building macOS app...${NC}"
flutter build macos --release

# 9. 원본 파일 복원
echo -e "${YELLOW}♻️  Restoring original files...${NC}"
mv pubspec_backup.yaml pubspec.yaml
mv lib/main_backup.dart lib/main.dart
mv temp_backup/* lib/services/ 2>/dev/null || true
rm -rf temp_backup

# 10. 빌드 결과 확인
if [ -d "build/macos/Build/Products/Release/SnapPay.app" ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${GREEN}📍 App location: build/macos/Build/Products/Release/SnapPay.app${NC}"
    
    # DMG 생성 옵션
    echo -e "\n${YELLOW}Would you like to create a DMG installer? (y/n)${NC}"
    read -r CREATE_DMG
    
    if [[ $CREATE_DMG =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}📀 Creating DMG...${NC}"
        rm -rf dmg_temp
        mkdir -p dmg_temp
        cp -R build/macos/Build/Products/Release/SnapPay.app dmg_temp/
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
    exit 1
fi