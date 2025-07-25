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
import 'package:workmanager/workmanager.dart';
import 'dart:io';

// WorkManager callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Handle background sync
    print("Background task executed: $task");
    return Future.value(true);
  });
}

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Windows에서 디버그 메시지
    if (Platform.isWindows) {
      print('[SnapPay] Starting Windows application...');
    }

    // Initialize connectivity service
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();

    // Android에서만 WorkManager 초기화
    if (Platform.isAndroid) {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true,
      );
      await Workmanager().cancelAll();
    }
  
  // Register periodic sync task - 비활성화
  // await Workmanager().registerPeriodicTask(
  //   "sync-notifications",
  //   "syncNotifications",
  //   frequency: const Duration(minutes: 15),
  //   constraints: Constraints(
  //     networkType: NetworkType.connected,
  //   ),
  // );
  
  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 화면 회전 방지 - 세로 모드로 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(RemocallApp(connectivityService: connectivityService));
}

class RemocallApp extends StatelessWidget {
  final ConnectivityService connectivityService;
  
  const RemocallApp({
    super.key,
    required this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: connectivityService),
      ],
      child: AppInitializer(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              title: 'SnapPay',
              debugShowCheckedModeBanner: false,
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
                child: SplashScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
