import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/providers/theme_provider.dart';
import 'package:remocall_flutter/screens/auth/pin_login_screen.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:remocall_flutter/services/update_service.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:remocall_flutter/utils/type_utils.dart';
import 'package:remocall_flutter/config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:remocall_flutter/screens/settings/settings_screen.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.remocall/notifications');
  final currencyFormatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
  bool _isLoading = true;
  Map<String, dynamic>? _shopData;
  // Timer? _refreshTimer; // 자동 갱신 제거됨
  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  final GlobalKey _updateButtonKey = GlobalKey();
  
  // 권한 및 상태 변수
  bool _hasNotificationAccess = false;
  bool _isServiceRunning = false;
  bool _isPowerSaveMode = false;
  bool _isAccessibilityServiceEnabled = false;
  Timer? _statusTimer;
  String _appVersion = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShopProfileInitial();
    _startAutoRefresh();
    _loadAppVersion();
    if (Platform.isAndroid) {
      _checkPermissionsAndStatus();  // Android에서만 권한 체크
    }
    
    // Check if navigated from update dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ModalRoute.of(context)?.settings.arguments == 'scrollToUpdate') {
        _scrollToUpdateButton();
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // 앱이 포그라운드로 돌아왔을 때 권한 상태 재확인
      print('[ShopProfile] App resumed, checking permissions...');
      _checkPermissionsAndStatus();
    }
    
    // Windows에서 앱 상태에 따라 타이머 관리
    if (Platform.isWindows) {
      if (state == AppLifecycleState.resumed) {
        _startAutoRefresh();
      } else if (state == AppLifecycleState.paused) {
        _refreshTimer?.cancel();
      }
    }
  }
  
  void _scrollToUpdateButton() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_updateButtonKey.currentContext != null) {
        Scrollable.ensureVisible(
          _updateButtonKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      print('Error loading app version: $e');
      // 폴백으로 하드코딩된 버전 사용
      if (mounted) {
        setState(() {
          _appVersion = AppConfig.appVersion;
        });
      }
    }
  }
  
  
  Future<void> _checkPermissionsAndStatus() async {
    // Android에서만 작동
    if (!Platform.isAndroid) {
      setState(() {
        _hasNotificationAccess = false;
        _isServiceRunning = false;
        _isPowerSaveMode = false;
      });
      return;
    }
    
    try {
      print('[ShopProfile] Checking permissions...');
      
      // 알림 권한 체크
      final hasPermission = await platform.invokeMethod('checkNotificationPermission');
      final isRunning = await platform.invokeMethod('isServiceRunning');
      
      // 접근성 서비스 체크
      final isAccessibilityEnabled = await platform.invokeMethod('isAccessibilityServiceEnabled');
      
      // 배터리 설정 체크
      final batterySettings = await platform.invokeMethod('getBatterySettings') as Map<dynamic, dynamic>?;
      
      print('[ShopProfile] Permission check results:');
      print('  - hasNotificationAccess: $hasPermission');
      print('  - isServiceRunning: $isRunning');
      print('  - isAccessibilityEnabled: $isAccessibilityEnabled');
      print('  - batterySettings: $batterySettings');
      
      if (mounted) {
        setState(() {
          _hasNotificationAccess = hasPermission ?? false;
          _isServiceRunning = isRunning ?? false;
          _isAccessibilityServiceEnabled = isAccessibilityEnabled ?? false;
          
          if (batterySettings != null) {
            _isPowerSaveMode = batterySettings['powerSaveMode'] ?? false;
          }
          
          print('[ShopProfile] UI State updated:');
          print('  - _hasNotificationAccess: $_hasNotificationAccess');
          print('  - _isServiceRunning: $_isServiceRunning');
          print('  - _isPowerSaveMode (절전 모드): $_isPowerSaveMode');
        });
      }
    } on PlatformException catch (e) {
      print('Error checking permissions and status: ${e.message}');
    }
  }
  
  void _startAutoRefresh() {
    // Windows에서만 자동 갱신
    if (Platform.isWindows) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _loadShopProfileBackground(),
      );
      print('[ShopProfile] Windows auto refresh started');
    }
  }
  
  Future<void> _loadShopProfileInitial() async {
    setState(() {
      _isLoading = true;
    });
    await _loadShopProfile();
    await _checkPermissionsAndStatus();  // 새로고침 시 권한 체크
  }
  
  Future<void> _loadShopProfileBackground() async {
    // 백그라운드에서는 realtime API 사용
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      try {
        final apiService = ApiService();
        final response = await apiService.getRealTimeData(authProvider.accessToken!);
        
        if (response['success'] == true && response['data'] != null && mounted) {
          setState(() {
            // realtime API에서는 shop 정보가 없으므로 기존 데이터 유지
            if (_shopData != null && response['data']['shop'] != null) {
              _shopData = response['data']['shop'];
            }
          });
        }
      } catch (e) {
        print('Error loading realtime data: $e');
      }
    }
  }
  
  Future<void> _loadShopProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      try {
        final apiService = ApiService();
        // 통합 API 사용
        final response = await apiService.getInitialData(authProvider.accessToken!);
        
        if (response['success'] == true && response['data'] != null && mounted) {
          setState(() {
            _shopData = response['data']['shop'];
            _isLoading = false;
          });
          
          // Update AuthProvider with latest shop data
          if (_shopData != null) {
            authProvider.updateShopData(_shopData!);
          }
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading shop profile: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const PinLoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final shop = authProvider.currentShop;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('매장 정보'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadShopProfileInitial,
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 매장 기본 정보
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.9),
                          AppTheme.primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.store,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shop?.name ?? '매장명',
                                    style: AppTheme.headlineSmall.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '매장 코드: ${shop?.code ?? ''}',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 상세 정보
                  if (_shopData != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '매장 상세 정보',
                            style: AppTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('매장 유형', _shopData!['type'] ?? ''),
                          if (_shopData!['pricing_plan_name'] != null)
                            _buildInfoRow('정산 방식', _shopData!['pricing_plan_name']),
                          // 요율 방식인 경우 수수료율 표시
                          if (_shopData!['pricing_plan'] == 'prepaid_with_fee' && _shopData!['fee_rate'] != null)
                            _buildInfoRow('수수료율', '${_shopData!['fee_rate']}%'),
                          // 월정액 방식인 경우 월정액 표시
                          if (_shopData!['pricing_plan'] == 'monthly_flat_fee' && _shopData!['monthly_flat_fee_amount'] != null)
                            _buildInfoRow('월정액', currencyFormatter.format(
                              TypeUtils.safeToDouble(_shopData!['monthly_flat_fee_amount'])
                            )),
                          if (_shopData!['settlement_day'] != null)
                            _buildInfoRow('정산일', '매월 ${_shopData!['settlement_day']}일'),
                          const Divider(height: 24),
                          _buildInfoRow(
                            '상태',
                            _shopData!['is_active'] == true ? '활성' : '비활성',
                            valueColor: _shopData!['is_active'] == true 
                                ? AppTheme.successColor 
                                : Colors.red,
                          ),
                          if (_shopData!['created_at'] != null)
                            _buildInfoRow(
                              '가입일',
                              DateTimeUtils.getKSTDateString(
                                DateTimeUtils.parseToKST(_shopData!['created_at'])
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  
                  // const SizedBox(height: 20),
                  
                  // // 테마 설정
                  // Container(
                  //   width: double.infinity,
                  //   padding: const EdgeInsets.all(20),
                  //   decoration: BoxDecoration(
                  //     color: Theme.of(context).cardTheme.color,
                  //     borderRadius: BorderRadius.circular(16),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: Theme.of(context).brightness == Brightness.dark
                  //             ? Colors.black.withOpacity(0.3)
                  //             : Colors.grey.withOpacity(0.1),
                  //         blurRadius: 10,
                  //         offset: const Offset(0, 4),
                  //       ),
                  //     ],
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         '디스플레이 설정',
                  //         style: AppTheme.headlineSmall,
                  //       ),
                  //       const SizedBox(height: 16),
                  //       Consumer<ThemeProvider>(
                  //         builder: (context, themeProvider, child) {
                  //           return Row(
                  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //             children: [
                  //               Row(
                  //                 children: [
                  //                   Icon(
                  //                     themeProvider.isDarkMode
                  //                         ? Icons.dark_mode
                  //                         : Icons.light_mode,
                  //                     color: AppTheme.primaryColor,
                  //                   ),
                  //                   const SizedBox(width: 12),
                  //                   Text(
                  //                     '다크 모드',
                  //                     style: AppTheme.bodyLarge,
                  //                   ),
                  //                 ],
                  //               ),
                  //               Switch(
                  //                 value: themeProvider.isDarkMode,
                  //                 onChanged: (value) {
                  //                   themeProvider.toggleTheme();
                  //                 },
                  //                 activeColor: AppTheme.primaryColor,
                  //               ),
                  //             ],
                  //           );
                  //         },
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  
                  // 권한 및 상태 정보 (Android에서만 표시)
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 20),
                    Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '알림 설정 상태',
                          style: AppTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow('알림 접근 권한', _hasNotificationAccess, Icons.notifications,
                          onSettingsTap: !_hasNotificationAccess ? () => _openNotificationSettings() : null),
                        const SizedBox(height: 12),
                        _buildStatusRow('알림 모니터링 작동 중', _isServiceRunning, Icons.monitor_heart,
                          onSettingsTap: !_isServiceRunning ? () => _openNotificationSettings() : null),
                        const SizedBox(height: 12),
                        _buildStatusRow('자동 잠금해제', _isAccessibilityServiceEnabled, Icons.lock_open,
                          onSettingsTap: !_isAccessibilityServiceEnabled ? () => _openAccessibilitySettings() : null),
                        const SizedBox(height: 24),
                        Text(
                          '배터리 설정',
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow('절전 모드 비활성화', !_isPowerSaveMode, Icons.power_settings_new, 
                          subtitle: _isPowerSaveMode ? '절전 모드가 켜져 있습니다' : null,
                          onSettingsTap: _isPowerSaveMode ? () => _openBatterySettings() : null),
                      ],
                    ),
                  ),
                  ],
                  
                  // 앱 버전 정보 및 업데이트 (모바일에서만 표시)
                  if (!Platform.isWindows && !Platform.isMacOS) ...[
                    const SizedBox(height: 20),
                    
                    // 앱 정보 섹션
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildInfoRow('현재 버전', _appVersion.isEmpty ? '로딩 중...' : 'v$_appVersion'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 업데이트 버튼
                    SizedBox(
                      key: _updateButtonKey,
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingUpdate ? null : _checkAndUpdate,
                        icon: const Icon(Icons.system_update),
                        label: const Text(
                          '업데이트 확인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // 로그아웃 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        '로그아웃',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
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
  
  Future<void> _checkAndUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
    });
    
    try {
      // 업데이트 확인
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final updateInfo = await _updateService.checkForUpdate(
        accessToken: authProvider.accessToken,
      );
      
      if (updateInfo != null && mounted) {
        // 업데이트 가능
        final shouldUpdate = await showDialog<bool>(
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
                onPressed: () => Navigator.pop(context, false),
                child: const Text('나중에'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('업데이트 시작'),
              ),
            ],
          ),
        );
        
        if (shouldUpdate == true) {
          await _downloadAndInstall(updateInfo);
        }
      } else if (mounted) {
        // 최신 버전
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현재 최신 버전입니다'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업데이트 확인 실패: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }
  
  Future<void> _downloadAndInstall(UpdateInfo updateInfo) async {
    bool downloadCompleted = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 다운로드 시작
          if (!downloadCompleted) {
            _updateService.downloadAndInstallUpdate(
              downloadUrl: updateInfo.downloadUrl,
              onProgress: (progress) {
                if (progress >= 1.0 && !downloadCompleted) {
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
      ),
    );
  }
  

  void _openNotificationSettings() async {
    try {
      await platform.invokeMethod('requestNotificationPermission');
      // 1초 후 상태 재확인
      Future.delayed(const Duration(seconds: 1), () {
        _checkPermissionsAndStatus();
      });
    } on PlatformException catch (e) {
      print('Failed to request permission: ${e.message}');
    }
  }

  void _openBatterySettings() async {
    try {
      await platform.invokeMethod('openBatterySettings');
    } catch (e) {
      print('Error opening battery settings: $e');
    }
  }
  
  void _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
      // 설정에서 돌아올 때 상태 재확인
      Timer(const Duration(seconds: 1), () {
        _checkPermissionsAndStatus();
      });
    } catch (e) {
      print('Error opening accessibility settings: $e');
    }
  }

  Widget _buildStatusRow(String label, bool status, IconData icon, {
    bool isGoodWhenTrue = true, 
    String? subtitle,
    VoidCallback? onSettingsTap,
  }) {
    final isGood = isGoodWhenTrue ? status : !status;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isGood ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (onSettingsTap != null && !isGood)
              GestureDetector(
                onTap: onSettingsTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '설정하기',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isGood ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status ? '확인' : '미확인',
                  style: TextStyle(
                    color: isGood ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}