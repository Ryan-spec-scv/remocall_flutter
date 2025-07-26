import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/providers/transaction_provider.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:intl/intl.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  static const platform = MethodChannel('com.remocall/notifications');
  bool _isServiceRunning = false;
  bool _hasPermission = false;
  // Timer? _statusTimer; // 자동 갱신 제거됨
  final TextEditingController _testMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkStatus();
    
    // 기본 테스트 메시지 설정
    _testMessageController.text = '이현우(이*우)님이 10,000원을 보냈어요.';
    
    // 자동 갱신 제거 - 수동 새로고침만 사용
    _checkStatus(); // 초기 상태만 확인
  }
  
  @override
  void dispose() {
    // _statusTimer?.cancel(); // 자동 갱신 제거됨
    _testMessageController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final isRunning = await platform.invokeMethod('isServiceRunning');
      final hasPermission = await platform.invokeMethod('checkNotificationPermission');
      
      setState(() {
        _isServiceRunning = isRunning ?? false;
        _hasPermission = hasPermission ?? false;
      });
    } on PlatformException catch (e) {
      print('Error checking status: ${e.message}');
    }
  }

  Future<void> _sendTestNotification() async {
    // 사용자가 입력한 메시지 가져오기
    final testMessage = _testMessageController.text.trim();
    
    if (testMessage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('테스트 메시지를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // Native 코드에서 테스트 알림만 생성 (서버 전송은 NotificationService가 처리)
      final result = await platform.invokeMethod('sendTestWebhook', {
        'message': testMessage,
      });
      
      // 알림 생성 결과 처리
      final success = result['success'] as bool;
      final responseMessage = result['message'] as String;
      
      // 테스트 알림 생성 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(responseMessage),
          backgroundColor: success ? AppTheme.successColor : Colors.red,
        ),
      );
      
      // 알림이 NotificationService에 의해 감지되고 서버로 전송될 것임
      print('Test notification created, waiting for NotificationService to detect and send...');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테스트 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final notifications = notificationProvider.notifications;
    final provider = notificationProvider; // for easier access
    // dateFormatter removed - will use DateTimeUtils directly

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 파싱 테스트'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 상태 카드
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[100],
            child: Column(
              children: [
                _buildStatusRow('알림 접근 권한', _hasPermission),
                const SizedBox(height: 8),
                _buildStatusRow('NotificationListener 실행 중', _isServiceRunning),
                const SizedBox(height: 8),
                // 모드 전환 스위치 추가
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: provider.isSnapPayMode ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '알림 인식 모드',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            provider.isSnapPayMode 
                                ? 'SnapPay 알림만 인식합니다' 
                                : '카카오페이 알림만 인식합니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: provider.isSnapPayMode ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            provider.isSnapPayMode ? 'SnapPay' : 'KakaoPay',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: provider.isSnapPayMode ? Colors.blue : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: provider.isSnapPayMode,
                            onChanged: (value) async {
                              await provider.setNotificationMode(value);
                            },
                            activeColor: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 테스트 메시지 입력 필드
                TextField(
                  controller: _testMessageController,
                  decoration: InputDecoration(
                    labelText: '테스트 메시지',
                    hintText: '예: 홍길동(홍*동)님이 50,000원을 보냈어요.',
                    labelStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : null,
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : null,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => _testMessageController.clear(),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _checkStatus,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('상태 갱신', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _sendTestNotification,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('테스트', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final provider = Provider.of<NotificationProvider>(context, listen: false);
                          await provider.retrySendingFailedNotifications();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('실패한 알림을 다시 전송하고 있습니다'),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          );
                        },
                        icon: const Icon(Icons.cloud_upload, size: 18),
                        label: const Text('재전송', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 알림 목록
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '수신된 알림이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '카카오톡 입금 알림이 오면 여기에 표시됩니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final parsedData = notification.parsedData;
                      final isFinancial = parsedData != null && parsedData['type'] != 'unknown';

                      return Card(
                        color: isFinancial 
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.green[900]?.withOpacity(0.3)
                                : Colors.green[50])
                            : null,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isFinancial ? Icons.attach_money : Icons.message,
                                    color: isFinancial ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    notification.sender,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  // 서버 전송 상태 표시
                                  if (isFinancial) ...[
                                    Tooltip(
                                      message: notification.isServerSent 
                                        ? '서버 전송 완료' 
                                        : notification.errorMessage != null 
                                          ? '전송 실패: ${notification.errorMessage}'
                                          : '서버 전송 대기',
                                      child: Icon(
                                        notification.isServerSent
                                          ? Icons.cloud_done
                                          : notification.errorMessage != null
                                            ? Icons.cloud_off
                                            : Icons.cloud_upload,
                                        color: notification.isServerSent
                                          ? Colors.green
                                          : notification.errorMessage != null
                                            ? Colors.red
                                            : Colors.orange,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    DateTimeUtils.formatKST(notification.receivedAt, 'MM/dd HH:mm:ss'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.message,
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (isFinancial) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.green[900]?.withOpacity(0.3)
                                        : Colors.green[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '파싱 결과',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.green[400]
                                              : Colors.green[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildParsedInfo('유형', parsedData['type']),
                                      _buildParsedInfo('금액', '${parsedData['amount']}원'),
                                      if (parsedData['from'] != null)
                                        _buildParsedInfo('보낸 사람', parsedData['from']),
                                      if (parsedData['balance'] != null)
                                        _buildParsedInfo('잔액', '${parsedData['balance']}원'),
                                    ],
                                  ),
                                ),
                                if (notification.errorMessage != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.red[900]?.withOpacity(0.3)
                                          : Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.red[400]
                                              : Colors.red,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            notification.errorMessage!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.red[400]
                                                  : Colors.red[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[300]
                : Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          status ? '활성화' : '비활성화',
          style: TextStyle(
            color: status ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildParsedInfo(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.green[400]
                  : Colors.green[700],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.green[300]
                  : Colors.green[900],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}