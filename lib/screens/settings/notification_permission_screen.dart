import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:remocall_flutter/services/notification_service.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/widgets/custom_button.dart';

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> {
  bool _isPermissionGranted = false;
  bool _isChecking = true;
  
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }
  
  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    
    final hasPermission = await NotificationService.instance.checkNotificationPermission();
    
    if (mounted) {
      setState(() {
        _isPermissionGranted = hasPermission;
        _isChecking = false;
      });
    }
  }
  
  Future<void> _requestPermission() async {
    await NotificationService.instance.requestNotificationPermission();
    
    // Wait a bit for user to grant permission
    await Future.delayed(const Duration(seconds: 1));
    _checkPermission();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '알림 권한 설정',
          style: AppTheme.headlineSmall,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _isPermissionGranted
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPermissionGranted
                          ? Icons.check_circle
                          : Icons.notifications_off,
                      size: 60,
                      color: _isPermissionGranted
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ).animate().fadeIn().scale(),
                  
                  const SizedBox(height: 32),
                  
                  // Status Text
                  Text(
                    _isPermissionGranted
                        ? '알림 권한이 활성화되었습니다'
                        : '알림 권한이 필요합니다',
                    style: AppTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    _isPermissionGranted
                        ? '이제 카카오톡 알림을 자동으로 읽을 수 있습니다'
                        : '카카오톡 알림을 읽어 거래내역을 자동으로 기록하려면\n알림 접근 권한이 필요합니다',
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms),
                  
                  const SizedBox(height: 48),
                  
                  if (!_isPermissionGranted) ...[
                    // Instructions
                    _buildInstructionCard().animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 32),
                    
                    // Permission Button
                    CustomButton(
                      text: '권한 설정하기',
                      onPressed: _requestPermission,
                      isGradient: true,
                      icon: Icons.settings,
                    ).animate().fadeIn(delay: 500.ms),
                  ] else ...[
                    // Success Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.infoColor,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '알림 서비스 작동 중',
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '카카오톡에서 금융 관련 알림이 오면\n자동으로 거래내역이 기록됩니다',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Test Button
                    CustomButton(
                      text: '테스트 알림 보내기',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('테스트 기능은 준비 중입니다'),
                          ),
                        );
                      },
                      isOutlined: true,
                      icon: Icons.science,
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Refresh Button
                  TextButton.icon(
                    onPressed: _checkPermission,
                    icon: const Icon(Icons.refresh),
                    label: const Text('권한 상태 새로고침'),
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInstructionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '설정 방법',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              '1',
              '아래 "권한 설정하기" 버튼을 누르세요',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '2',
              '설정 화면에서 "리모콜"을 찾아주세요',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '3',
              '스위치를 켜서 알림 접근을 허용해주세요',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '4',
              '뒤로 돌아와서 권한 상태를 확인하세요',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}