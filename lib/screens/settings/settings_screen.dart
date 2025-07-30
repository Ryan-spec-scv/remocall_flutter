import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/screens/auth/pin_login_screen.dart';
import 'package:remocall_flutter/screens/settings/notification_permission_screen.dart';
import 'package:remocall_flutter/screens/settings/test_token_screen.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/config/app_config.dart';
import 'dart:io';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final shop = authProvider.currentShop;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '설정',
          style: AppTheme.headlineSmall,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        shop?.name.substring(0, 1).toUpperCase() ?? 'S',
                        style: AppTheme.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    shop?.name ?? '매장',
                    style: AppTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shop?.code ?? '',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Settings Items
            _buildSettingItem(
              icon: Icons.person_outline,
              title: '프로필 편집',
              onTap: () {
                // TODO: Navigate to profile edit
              },
            ),
            _buildSettingItem(
              icon: Icons.notifications_outlined,
              title: '알림 권한 설정',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationPermissionScreen(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.security_outlined,
              title: '보안 설정',
              onTap: () {
                // TODO: Navigate to security settings
              },
            ),
            _buildSettingItem(
              icon: Icons.help_outline,
              title: '도움말',
              onTap: () {
                // TODO: Navigate to help
              },
            ),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: '앱 정보',
              subtitle: '버전 ${AppConfig.appVersion}',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: '리모콜',
                  applicationVersion: AppConfig.appVersion,
                  applicationLegalese: '© 2024 Remocall',
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.science_outlined,
              title: '토큰 갱신 테스트',
              subtitle: '개발자 옵션',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TestTokenScreen(),
                  ),
                );
              },
            ),
            if (Platform.isAndroid)
              _buildSettingItem(
                icon: Icons.upload_outlined,
                title: '로그 즉시 업로드',
                subtitle: 'GitHub로 로그 파일 전송',
                onTap: () async {
                  _showUploadDialog(context);
                },
              ),
            
            const Divider(),
            
            // Logout
            _buildSettingItem(
              icon: Icons.logout,
              title: '로그아웃',
              titleColor: AppTheme.errorColor,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          '로그아웃',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PinLoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                }
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('로그 업로드'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('로그 파일을 GitHub로 업로드하는 중...'),
            ],
          ),
        );
      },
    );

    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.remocall/notifications');
        final result = await platform.invokeMethod('triggerLogUpload');
        
        if (context.mounted) {
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그 업로드가 시작되었습니다'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그 업로드 실패: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? Colors.grey[700],
      ),
      title: Text(
        title,
        style: AppTheme.bodyLarge.copyWith(
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}