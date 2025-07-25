import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/screens/auth/pin_login_screen.dart';
import 'package:remocall_flutter/screens/settings/notification_permission_screen.dart';
import 'package:remocall_flutter/utils/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

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
                        user?.name.substring(0, 1).toUpperCase() ?? 'U',
                        style: AppTheme.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? '사용자',
                    style: AppTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
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
              subtitle: '버전 1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: '리모콜',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 Remocall',
                );
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