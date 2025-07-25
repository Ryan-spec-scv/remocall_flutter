import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/providers/transaction_provider.dart';
import 'package:remocall_flutter/services/notification_service.dart';
import 'package:remocall_flutter/services/update_service.dart';
import 'package:remocall_flutter/screens/profile/shop_profile_screen.dart';
import 'package:remocall_flutter/utils/theme.dart';

class AppInitializer extends StatefulWidget {
  final Widget child;
  
  const AppInitializer({
    super.key,
    required this.child,
  });

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> with WidgetsBindingObserver {
  final UpdateService _updateService = UpdateService();
  bool _hasCheckedUpdate = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize notification service after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      final transactionProvider = context.read<TransactionProvider>();
      
      NotificationService.instance.initialize(
        notificationProvider: notificationProvider,
        transactionProvider: transactionProvider,
      );
      
      // Update notification provider token when auth changes
      authProvider.addListener(() {
        notificationProvider.updateAccessToken(authProvider.accessToken);
      });
      
      // Set initial token
      notificationProvider.updateAccessToken(authProvider.accessToken);
      
      // Check for update when app starts
      _checkForUpdateIfNeeded();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdateIfNeeded();
    }
  }
  
  Future<void> _checkForUpdateIfNeeded() async {
    final authProvider = context.read<AuthProvider>();
    
    // Only check if user is logged in and not on login page
    if (authProvider.accessToken != null && !_hasCheckedUpdate) {
      _hasCheckedUpdate = true;
      
      try {
        final updateInfo = await _updateService.checkForUpdate(
          accessToken: authProvider.accessToken,
        );
        
        if (updateInfo != null && mounted) {
          _showUpdateDialog();
        }
      } catch (e) {
        print('업데이트 체크 실패: $e');
      }
      
      // Reset flag after 5 minutes to check again
      Future.delayed(const Duration(minutes: 5), () {
        _hasCheckedUpdate = false;
      });
    }
  }
  
  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('업데이트 알림'),
        content: const Text('최신버전으로 업데이트 해주세요'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // 업데이트 정보 다시 가져오기
              final authProvider = context.read<AuthProvider>();
              final updateInfo = await _updateService.checkForUpdate(
                accessToken: authProvider.accessToken,
              );
              if (updateInfo != null) {
                // 바로 업데이트 다이얼로그 표시
                _showUpdateInstallDialog(updateInfo);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  void _showUpdateInstallDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('새 버전 업데이트'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '버전 ${updateInfo.version} 업데이트 가능',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '설치 방법 안내',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildInstallStep(
              '1',
              '다운로드가 완료되면 설치 화면이 나타납니다',
            ),
            _buildInstallStep(
              '2',
              '"알 수 없는 출처" 경고가 나타나면 "설정"을 눌러주세요',
            ),
            _buildInstallStep(
              '3',
              '"이 출처 허용" 스위치를 켜주세요',
            ),
            _buildInstallStep(
              '4',
              '뒤로 가기 후 "설치"를 눌러주세요',
            ),
            _buildInstallStep(
              '5',
              '앱 검사 화면이 나타나면 "무시하고 설치"를 선택하세요',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '설치 후 자동으로 앱이 재시작됩니다',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadAndInstall(updateInfo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('업데이트 시작'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstallStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _downloadAndInstall(UpdateInfo updateInfo) async {
    bool downloadCompleted = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(Duration.zero, () async {
          if (!downloadCompleted) {
            _updateService.downloadAndInstallUpdate(
              downloadUrl: updateInfo.downloadUrl,
              onProgress: (progress) {
                if (mounted && !downloadCompleted && progress >= 1.0) {
                  downloadCompleted = true;
                  Navigator.pop(context);
                }
              },
              context: context,
            ).catchError((e) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('업데이트 실패: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            });
          }
        });
        
        return AlertDialog(
          title: const Text('업데이트 다운로드 중'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              const Text('잠시만 기다려주세요...'),
            ],
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}