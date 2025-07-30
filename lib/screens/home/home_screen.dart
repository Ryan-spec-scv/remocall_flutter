import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/providers/transaction_provider.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/screens/profile/shop_profile_screen.dart';
import 'package:remocall_flutter/screens/test/notification_test_screen.dart';
import 'package:remocall_flutter/screens/transactions/transactions_screen.dart';
import 'package:remocall_flutter/screens/deposit/manual_deposit_screen.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/widgets/transaction_list_item.dart';
import 'package:remocall_flutter/widgets/dashboard_summary.dart';
import 'package:remocall_flutter/services/update_service.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.remocall/notifications');
  bool _hasNotificationAccess = false;
  bool _isAccessibilityServiceEnabled = false;
  // Timer? _refreshTimer; // 자동 갱신 제거됨
  bool _isFirstLoad = true;
  final UpdateService _updateService = UpdateService();
  bool _hasCheckedUpdate = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Android에서만 알림 권한 체크
    if (Platform.isAndroid) {
      _checkNotificationPermission();
      _checkAccessibilityService(); // 접근성 서비스 체크
    }
    _loadDataInitial();
    _checkForUpdate(); // 업데이트 체크 추가
    
    // 자동 갱신 제거 - 수동 새로고침만 사용
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // _refreshTimer?.cancel(); // 자동 갱신 제거됨
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // 앱이 포그라운드로 돌아왔을 때 접근성 서비스 상태 재확인
      print('[HomeScreen] App resumed, checking accessibility service status...');
      _checkAccessibilityService();
    }
  }
  
  Future<void> _checkNotificationPermission() async {
    // Android에서만 작동
    if (!Platform.isAndroid) return;
    
    try {
      print('[HomeScreen] Checking notification permission...');
      final bool hasPermission = await platform.invokeMethod('checkNotificationPermission');
      print('[HomeScreen] Notification permission status: $hasPermission');
      
      if (mounted) {
        setState(() {
          _hasNotificationAccess = hasPermission;
        });
      }
      
      if (!hasPermission && mounted) {
        print('[HomeScreen] Showing permission dialog...');
        _showNotificationPermissionDialog();
      }
    } on PlatformException catch (e) {
      print('Failed to check notification permission: ${e.message}');
      if (mounted) {
        setState(() {
          _hasNotificationAccess = false;
        });
      }
    }
  }
  
  Future<void> _checkAccessibilityService() async {
    if (!Platform.isAndroid) return;
    
    try {
      final bool isEnabled = await platform.invokeMethod('isAccessibilityServiceEnabled');
      print('[HomeScreen] Accessibility service status: $isEnabled');
      
      if (mounted) {
        setState(() {
          _isAccessibilityServiceEnabled = isEnabled;
        });
      }
      
      // Android 11 사용자를 위한 특별 안내
      if (!isEnabled && Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt == 30) { // Android 11
          _showAndroid11Guide();
        }
      }
    } on PlatformException catch (e) {
      print('Failed to check accessibility service: ${e.message}');
      if (mounted) {
        setState(() {
          _isAccessibilityServiceEnabled = false;
        });
      }
    }
  }
  
  void _showAndroid11Guide() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Android 11 안내', style: AppTheme.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Android 11에서는 추가 권한이 필요합니다:', style: AppTheme.bodyMedium),
            const SizedBox(height: 12),
            Text('1. 접근성 설정에서 SnapPay 선택', style: AppTheme.bodySmall),
            Text('2. "제한된 설정 사용" 버튼 클릭', style: AppTheme.bodySmall),
            Text('3. 경고창에서 "허용" 선택', style: AppTheme.bodySmall),
            const SizedBox(height: 12),
            Text('이 과정은 한 번만 필요합니다.', 
              style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              platform.invokeMethod('openAccessibilitySettings');
            },
            child: Text('설정으로 이동'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('나중에'),
          ),
        ],
      ),
    );
  }
  
  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('알림 접근 권한 필요'),
          content: const Text(
            '카카오페이 알림을 자동으로 파싱하려면\n'
            '알림 접근 권한이 필요합니다.\n\n'
            '설정에서 SnapPay 앱의 알림 접근을 허용해주세요.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await platform.invokeMethod('requestNotificationPermission');
                  Future.delayed(const Duration(seconds: 1), () {
                    _checkNotificationPermission();
                  });
                } on PlatformException catch (e) {
                  print('Failed to request permission: ${e.message}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadDataInitial() async {
    // 새로고침 시 권한 다시 체크
    await _checkNotificationPermission();
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      // initial API만 호출 (recent_transactions 포함)
      await transactionProvider.loadDashboard(authProvider.accessToken!);
    }
    _isFirstLoad = false;
  }
  
  Future<void> _loadDataBackground() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      print('[HomeScreen] Background refresh started...');
      // 백그라운드에서는 realtime API만 사용
      await transactionProvider.loadRealtimeData(authProvider.accessToken!);
      print('[HomeScreen] Background refresh completed');
    }
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final shop = authProvider.currentShop;
    
    return Scaffold(
      body: _buildHomeTab(),
      floatingActionButton: shop?.code == '0701' 
        ? FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationTestScreen(),
                ),
              );
            },
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.notifications_active),
          )
        : null,
    );
  }

  Widget _buildHomeTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final shop = authProvider.currentShop;
    final currencyFormatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    
    return SafeArea(
      child: Column(
        children: [
          // 접근성 서비스 비활성화 배너
          if (!_isAccessibilityServiceEnabled && Platform.isAndroid)
            Material(
              color: Colors.orange.shade100,
              child: InkWell(
                onTap: () async {
                  try {
                    await platform.invokeMethod('openAccessibilitySettings');
                  } catch (e) {
                    print('Failed to open accessibility settings: $e');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, 
                        color: Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '카카오페이 자동 잠금해제가 비활성화되어 있습니다',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, 
                        color: Colors.orange.shade800,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDataInitial,
              displacement: 100,
              backgroundColor: AppTheme.primaryColor,
              color: Colors.white,
              strokeWidth: 4,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SnapPay',
                          style: AppTheme.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShopProfileScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shop?.name ?? '매장',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    '(${shop?.code ?? '0000'})',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                shop?.name.substring(0, 1) ?? 'S',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 600.ms),
                    
                    const SizedBox(height: 20),
                    
                    // 알림 권한 상태 표시 (Android에서만)
                    if (Platform.isAndroid && !_hasNotificationAccess)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warningColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warningColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '알림 접근 권한 필요',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                  Text(
                                    '카카오페이 알림 자동 파싱을 위해 설정이 필요합니다',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await platform.invokeMethod('requestNotificationPermission');
                                  Future.delayed(const Duration(seconds: 1), () {
                                    _checkNotificationPermission();
                                  });
                                } on PlatformException catch (e) {
                                  print('Failed to request permission: ${e.message}');
                                }
                              },
                              child: Text(
                                '설정',
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    
                    // Domain Info Card
                    if (shop != null && shop.domain != null && shop.domain!['has_domain'] == true)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.language,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                shop.domain!['full_domain'] ?? '',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: shop.domain!['full_domain'] ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('도메인이 클립보드에 복사되었습니다'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: AppTheme.primaryColor,
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms),
                    
                    
                    // Dashboard Summary
                    Builder(
                      builder: (context) {
                        print('===== HomeScreen DashboardSummary Debug =====');
                        print('transactionProvider.dashboardData: ${transactionProvider.dashboardData}');
                        print('dashboardData is null: ${transactionProvider.dashboardData == null}');
                        print('=============================================');
                        
                        return DashboardSummary(
                          dashboardData: transactionProvider.dashboardData,
                        );
                      },
                    ),
                    
                    // Recent Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '최근 입금내역',
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TransactionsScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '전체보기',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),
            ),
            
            // Transaction List
            Consumer<TransactionProvider>(
              builder: (context, provider, child) {
                // initial API의 recent_transactions 사용
                final recentTransactions = provider.recentTransactions;
                
                if (provider.isLoading && recentTransactions.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (recentTransactions.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '거래내역이 없습니다',
                            style: AppTheme.bodyLarge.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        children: [
                          // 헤더
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[850]
                                : Colors.grey[50],
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: totalWidth * 0.2,
                                      child: Text(
                                        'QR주소',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: totalWidth * 0.2,
                                      child: Text(
                                        '입금자',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: totalWidth * 0.4,
                                      child: Text(
                                        '금액',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: totalWidth * 0.2,
                                      child: Text(
                                        '날짜',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          // 리스트 아이템들
                          ...recentTransactions.map((transaction) => 
                            TransactionListItem(transaction: transaction)
                          ).toList(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Future<void> _checkForUpdate() async {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      try {
        print('[HomeScreen] Checking for update...');
        final updateInfo = await _updateService.checkForUpdate(
          accessToken: authProvider.accessToken,
        );
        
        if (updateInfo != null && mounted) {
          print('[HomeScreen] Update available: ${updateInfo.version}');
          _showUpdateDialog(updateInfo);
        } else {
          print('[HomeScreen] No update available');
        }
      } catch (e) {
        print('[HomeScreen] Update check failed: $e');
      }
    }
  }
  
  // 미완료건 경고 다이얼로그 제거
  
  void _showUpdateDialog(UpdateInfo updateInfo) {
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
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      strokeWidth: 4,
                    ),
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
}