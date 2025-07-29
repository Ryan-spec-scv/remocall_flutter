import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const platform = MethodChannel('com.remocall/notifications');
  bool _isPermissionGranted = false;
  bool _isAccessibilityEnabled = false;
  bool _isChecking = true;
  
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }
  
  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    
    final hasPermission = await NotificationService.instance.checkNotificationPermission();
    bool hasAccessibility = false;
    
    // Android에서만 접근성 서비스 확인
    if (Platform.isAndroid) {
      try {
        hasAccessibility = await platform.invokeMethod('isAccessibilityServiceEnabled');
      } catch (e) {
        print('Failed to check accessibility service: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isPermissionGranted = hasPermission;
        _isAccessibilityEnabled = hasAccessibility;
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
  
  Future<void> _requestAccessibilityPermission() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
      
      // 설정 화면에서 돌아올 때 상태 체크
      await Future.delayed(const Duration(seconds: 1));
      _checkPermission();
    } catch (e) {
      print('Failed to open accessibility settings: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '권한 설정',
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
                  // 권한 상태 카드들
                  _buildPermissionCard(
                    title: '알림 접근 권한',
                    description: '카카오톡 알림을 읽어 거래내역을 자동으로 기록합니다',
                    isEnabled: _isPermissionGranted,
                    onTap: _isPermissionGranted ? null : _requestPermission,
                  ).animate().fadeIn(),
                  
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    _buildPermissionCard(
                      title: '자동 잠금해제',
                      description: '카카오페이 알림 수신 시 자동으로 잠금화면을 해제합니다',
                      isEnabled: _isAccessibilityEnabled,
                      onTap: _isAccessibilityEnabled ? null : _requestAccessibilityPermission,
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // 전체 상태 표시
                  if (_isPermissionGranted && (!Platform.isAndroid || _isAccessibilityEnabled)) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.successColor,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '모든 권한이 활성화되었습니다',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '카카오톡 알림을 자동으로 처리할 수 있습니다',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
  
  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isEnabled,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled 
            ? AppTheme.successColor.withOpacity(0.3)
            : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEnabled
                    ? AppTheme.successColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEnabled ? Icons.check_circle : Icons.error_outline,
                  color: isEnabled ? AppTheme.successColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEnabled)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}