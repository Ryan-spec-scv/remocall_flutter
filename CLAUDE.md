# CLAUDE.md - SnapPay/Remocall Flutter Development Guide

## Language Setting
**한글로 대화하기** - 이 프로젝트 관련 모든 대화는 한글로 진행합니다.

## Project Overview

**SnapPay (리모콜)** is a cross-platform Flutter application for smart deposit management that automatically parses Korean financial notifications (KakaoTalk/KakaoPay/SnapPay) and manages transaction records. The app supports Android, iOS, macOS, and Windows with platform-specific functionality.

### Key Features
- 🔔 **Korean Financial Notification Parsing**: Automatically parses KakaoTalk payment notifications
- 💰 **Transaction Management**: Automatic income/expense categorization and statistics
- 🔄 **Real-time Sync**: WebSocket-based real-time server synchronization
- 📱 **Cross-platform**: Supports Android, iOS, macOS, Windows
- 🌐 **Offline Support**: Works offline with automatic sync when connected

### App Metadata
- **App Name**: SnapPay (리모콜)
- **Current Version**: 1.0.41+10041
- **Package**: com.remocall.remocall_flutter
- **Flutter SDK**: >=3.0.0 <4.0.0

## Build Commands & Development

### Prerequisites
```bash
# Check Flutter installation
flutter doctor

# Install dependencies  
flutter pub get

# iOS dependencies (macOS only)
cd ios && pod install && cd ..
```

### Build Commands

#### Android
```bash
# Debug build
flutter run

# Release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Using build script
./build_release.sh  # Creates APK with version info
```

#### macOS
```bash
# Automated macOS build (handles platform-specific setup)
./build_macos.sh

# Manual macOS build
flutter config --enable-macos-desktop
flutter build macos --release
# Output: build/macos/Build/Products/Release/SnapPay.app
```

#### Windows
```bash
# Windows build (Windows host only)
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

#### iOS
```bash
# iOS build
flutter build ios --release
cd ios && pod install && cd ..
flutter build ipa
```

### Testing & Linting
```bash
# Run tests
flutter test

# Code analysis
flutter analyze

# Format code
flutter format .
```

### Development Scripts
- `./auto_version.sh` - Automatic version bumping
- `./build_all.sh` - Build for multiple platforms
- `./build_with_notes.sh` - Build with release notes
- `./quick_build.sh` - Fast development build
- `./find_flutter.sh` - Locate Flutter installation
- `./sign_app_for_distribution.sh` - Code signing for distribution

## Project Architecture

### Directory Structure
```
remocall_flutter/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   └── app_config.dart         # Environment configuration
│   ├── models/                     # Data models
│   │   ├── user.dart
│   │   ├── shop.dart
│   │   ├── transaction_model.dart
│   │   └── notification_model.dart
│   ├── providers/                  # State management (Provider pattern)
│   │   ├── auth_provider.dart
│   │   ├── transaction_provider.dart  
│   │   ├── notification_provider.dart
│   │   └── theme_provider.dart
│   ├── screens/                    # UI screens
│   │   ├── auth/                   # Authentication
│   │   ├── home/                   # Dashboard
│   │   ├── transactions/           # Transaction history
│   │   ├── notifications/          # Notification settings
│   │   ├── settings/               # App settings
│   │   └── test/                   # Development/debug screens
│   ├── services/                   # Business logic & APIs
│   │   ├── api_service.dart        # REST API client
│   │   ├── websocket_service.dart  # Real-time communication
│   │   ├── database_service.dart   # Local SQLite database
│   │   ├── notification_service.dart # Notification handling
│   │   ├── connectivity_service.dart # Network monitoring
│   │   └── update_service.dart     # App update management
│   ├── utils/                      # Utilities
│   │   ├── theme.dart              # App theming
│   │   └── datetime_utils.dart     # Date/time helpers
│   └── widgets/                    # Reusable components
│       ├── app_initializer.dart
│       ├── connectivity_wrapper.dart
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── dashboard_summary.dart
│       ├── transaction_card.dart
│       └── transaction_list_item.dart
├── android/                        # Android native code
│   └── app/src/main/kotlin/com/remocall/remocall_flutter/
│       ├── MainActivity.kt
│       ├── NotificationService.kt   # Core notification listener (with queue system)
│       ├── LogManager.kt           # Logging system
│       ├── GitHubUploader.kt       # Log upload to GitHub
│       ├── GitHubSecrets.kt        # GitHub API credentials (gitignored)
│       ├── NotificationServiceWatchdog.kt # Service monitoring (10s interval)
│       └── SnapPayAccessibilityService.kt # Accessibility service for auto lockscreen unlock
├── ios/                            # iOS native code
├── macos/                          # macOS native code  
├── windows/                        # Windows native code
└── assets/                         # Static resources
    ├── images/
    ├── CHANGELOG.md
    └── release-metadata.json
```

## Platform-Specific Considerations

### Android
- **Notification Access**: Uses `NotificationListenerService` for KakaoTalk notification parsing
- **Background Processing**: `WorkManager` for periodic sync tasks
- **Permissions Required**: Notification access permission, overlay permission, accessibility service permission
- **Native Features**: Log management, GitHub integration, notification watchdog
- **Build Target**: API level 33+
- **Service Stability**: 
  - Permanent WakeLock for maximum reliability
  - 10-second JobScheduler check interval
  - Notification queue system with retry mechanism
  - ConcurrentHashMap for thread safety

### iOS  
- **Notification Limitations**: Cannot directly access third-party notifications due to iOS restrictions
- **Alternative Approaches**: Manual screenshot upload, KakaoTalk API integration, push notification server
- **Deployment**: Requires Apple Developer account for distribution

### macOS
- **Desktop Features**: Full-featured desktop application
- **Build Process**: Automated via `build_macos.sh` with platform-specific configuration
- **Distribution**: DMG packaging available
- **Special Handling**: Platform-specific main.dart during build

### Windows
- **Desktop App**: Read-only functionality (no notification parsing)
- **Features**: Data viewing, transaction history, statistics
- **Limitations**: No automatic updates, no notification parsing
- **Distribution**: ZIP archive with executable

## Key Services & Providers

### Authentication (AuthProvider)
- Shop-based authentication with PIN login
- Shop code format: 4 characters (alphanumeric, uppercase letters + numbers)
- JWT token management with automatic refresh
- Persistent session storage

### API Service (ApiService)
- REST API client with Dio
- Automatic token refresh interceptor  
- Error handling and retry logic
- Base URL switching (production/development)

### Transaction Management (TransactionProvider)
- Local SQLite database with real-time sync
- Automatic categorization of income/expenses
- Transaction filtering and statistics

### Notification Service
- **Android**: Native NotificationListenerService integration
- **Cross-platform**: Flutter notification handling
- Real-time notification processing and parsing

### WebSocket Service
- Real-time bidirectional communication
- Automatic reconnection handling
- Message queuing for offline scenarios

## Configuration & Environment

### Environment Configuration (app_config.dart)
```dart
// Production API
static const String apiBaseUrl = 'https://admin-api.snappay.online';

// Development API  
static const String apiBaseUrlDev = 'https://kakaopay-admin-api.flexteam.kr';

// Environment flag (set during build)
static const bool isProduction = bool.fromEnvironment('IS_PRODUCTION', defaultValue: true);
```

### Build Environment Variables
```bash
# Production build
flutter build apk --dart-define=IS_PRODUCTION=true

# Development build  
flutter build apk --dart-define=IS_PRODUCTION=false
```

### App Initialization Flow
1. Platform detection and configuration
2. Production mode storage in SharedPreferences
3. Notification queue cleanup (Android)
4. Connectivity service initialization
5. WorkManager setup (Android only)
6. System UI configuration
7. Provider initialization with dependency injection

## State Management

Uses **Provider** pattern with the following providers:
- `AuthProvider`: Authentication state and shop management
- `TransactionProvider`: Transaction data and local database
- `NotificationProvider`: Notification settings and status
- `ThemeProvider`: Dark/light theme management
- `ConnectivityService`: Network status monitoring

## Database Schema

Local SQLite database managed by `database_service.dart`:
- **Transactions**: Financial transaction records
- **Notifications**: Parsed notification data
- **Settings**: User preferences and configuration
- **Sync Status**: Offline/online synchronization tracking

## Dependencies & Key Packages

### UI & Animation
- `flutter_animate: ^4.3.0` - Smooth animations
- `google_fonts: ^6.1.0` - Typography
- `cupertino_icons: ^1.0.6` - iOS-style icons

### State Management  
- `provider: ^6.1.1` - State management pattern

### Networking
- `dio: ^5.4.0` - HTTP client
- `web_socket_channel: ^2.4.0` - WebSocket communication
- `connectivity_plus: ^5.0.2` - Network monitoring

### Local Storage
- `sqflite: ^2.3.0` - SQLite database
- `shared_preferences: ^2.2.2` - Key-value storage
- `path_provider: ^2.1.1` - File system paths

### Platform Integration
- `workmanager: ^0.6.0` - Background tasks (Android)
- `flutter_local_notifications: ^17.0.0` - Local notifications
- `permission_handler: ^11.1.0` - Runtime permissions

### Utilities
- `package_info_plus: ^8.0.0` - App metadata
- `url_launcher: ^6.2.2` - External URLs
- `uuid: ^4.2.1` - Unique identifiers
- `intl: ^0.20.2` - Internationalization

## Development Guidelines

### Code Style
- Follows Flutter/Dart official style guide
- Uses `flutter_lints: ^3.0.1` for code quality
- Korean comments for business logic, English for technical implementation

### Platform-Specific Code Patterns
```dart
// Platform detection
if (Platform.isAndroid) {
  // Android-specific implementation
} else if (Platform.isIOS) {
  // iOS-specific implementation  
} else if (Platform.isMacOS) {
  // macOS-specific implementation
} else if (Platform.isWindows) {
  // Windows-specific implementation
}

// Conditional imports
import 'package:workmanager/workmanager.dart'
    if (dart.library.html) 'main_stub.dart';
```

### Error Handling
- Comprehensive try-catch blocks with logging
- User-friendly error messages in Korean
- Automatic retry mechanisms for network operations
- Graceful degradation for platform-specific features

## Debugging & Logging

### Android Native Logging
- `LogManager.kt` - Centralized logging system
- Automatic log upload to GitHub for debugging
- Notification service monitoring and diagnostics

### Flutter Debugging
```bash
# Run with debug output
flutter run --verbose

# Hot reload during development
# Press 'r' to hot reload, 'R' to hot restart

# Debug with specific device
flutter run -d <device_id>
```

## Distribution & Updates

### Android Distribution
- APK generation with version metadata
- Automatic update checking via API
- Download and installation guidance for users
- Requires "Unknown Sources" permission

### GitHub Actions Integration
- Automated builds triggered by tags
- Multi-platform build support
- Artifact generation and release creation

### Update Mechanism
- Built-in update checker (`update_service.dart`)
- Server-side version management
- User notification for available updates
- Platform-specific update handling

## Common Development Tasks

### Adding a New Screen
1. Create screen file in appropriate `screens/` subdirectory
2. Add navigation route in main router
3. Update provider if state management needed
4. Add localization strings if required

### Adding API Endpoint
1. Add method to `api_service.dart`
2. Update models if new data structures needed
3. Add error handling and validation
4. Update provider to use new endpoint

### Platform-Specific Feature
1. Check platform capability in code
2. Implement native code if required (Android/iOS)
3. Add conditional compilation for web/desktop
4. Test across all target platforms

### Debugging Notification Parsing (Android)
1. Enable notification access in device settings
2. Check `NotificationService.kt` logs via Android Studio
3. Use test notification screen for development
4. Monitor log uploads to GitHub for production issues

## Troubleshooting

### Common Build Issues
- **CocoaPods**: Run `./fix_cocoapods_path.sh` or `./install_cocoapods.sh`
- **Flutter Path**: Use `./find_flutter.sh` to locate installation
- **macOS Build**: Use automated `build_macos.sh` script
- **Dependencies**: Run `flutter clean && flutter pub get`

### Platform-Specific Issues
- **Android**: Check notification permissions and accessibility settings
- **iOS**: Verify provisioning profiles and certificates
- **macOS**: Ensure Xcode command line tools installed
- **Windows**: Use Windows host machine for Windows builds

## Recent Updates

### Version 1.0.41 (2025-07-29)
- **Accessibility Service**: Implemented SnapPayAccessibilityService for automatic lockscreen dismissal on KakaoPay notifications
- **Enhanced Lockscreen Dismissal**: Added diagonal swipe gesture that successfully unlocks Samsung devices
- **UI Improvements**: Added accessibility service status indicators in home screen and settings
- **Floating Button Control**: Changed shop code condition from '0101' to '0701' for floating button visibility
- **Android 11 Compatibility**: 
  - Removed `canPerformGestures` from XML config to avoid "제한된 설정" warning
  - Implemented dynamic permission setting in `onServiceConnected()`
  - Added manufacturer-specific swipe patterns (Samsung, LG, Xiaomi)
  - Added Android 11 user guide dialog for permission instructions

### Version 1.0.40 (2025-07-29)
- **Notification Queue System**: Implemented queue-based notification sending with retry mechanism
- **Service Stability**: Enhanced Android service reliability with permanent WakeLock and faster monitoring
- **Shop Code Format**: Changed from numeric-only to alphanumeric (uppercase letters + numbers) 4-character format
- **GitHub Integration**: Secure credential management with GitHubSecrets.kt
- **UI Improvements**: Fixed mobile pagination layout to display 4 page buttons at a time for better mobile UX
- **Wake Screen on KakaoPay**: Simplified screen wake-up condition - now wakes screen for all KakaoPay notifications
- **Lockscreen Dismiss**: Enhanced lockscreen dismissal with KeyguardDismissCallback and additional Intent flags

This guide provides comprehensive information for Claude instances working with the SnapPay Flutter codebase. The application is a production Korean fintech app with complex notification parsing requirements and multi-platform deployment needs.