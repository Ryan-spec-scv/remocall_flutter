import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:remocall_flutter/screens/test/log_viewer_screen.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  static const platform = MethodChannel('com.remocall/notifications');
  bool _isServiceRunning = false;
  bool _hasPermission = false;
  final TextEditingController _testMessageController = TextEditingController();
  
  // 추가된 상태 변수들
  Map<String, dynamic>? _serviceHealth;
  List<dynamic> _recentLogs = [];
  List<dynamic> _failedQueueItems = [];
  Timer? _refreshTimer;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    
    // 기본 테스트 메시지 설정
    _testMessageController.text = '이현우(이*우)님이 10,000원을 보냈어요.';
    
    // 초기 데이터 로드
    _loadAllData();
    
    // 자동 새로고침 시작
    _startAutoRefresh();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _testMessageController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _loadAllData();
      });
    }
  }
  
  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    
    if (_autoRefresh) {
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }
  
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadServiceHealth(),
      _loadRecentLogs(),
      _loadFailedQueue(),
      _checkStatus(),
    ]);
  }
  
  Future<void> _loadServiceHealth() async {
    try {
      final healthJson = await platform.invokeMethod('getServiceHealthInfo');
      final health = jsonDecode(healthJson);
      if (mounted) {
        setState(() {
          _serviceHealth = health;
        });
      }
    } catch (e) {
      print('Error loading service health: $e');
    }
  }
  
  Future<void> _loadRecentLogs() async {
    try {
      final logsJson = await platform.invokeMethod('getRecentNotificationLogs');
      final logs = jsonDecode(logsJson);
      if (mounted) {
        setState(() {
          _recentLogs = logs is List ? logs : [];
        });
      }
    } catch (e) {
      print('Error loading recent logs: $e');
    }
  }
  
  Future<void> _loadFailedQueue() async {
    try {
      final queueJson = await platform.invokeMethod('getFailedQueueInfo');
      final queue = jsonDecode(queueJson);
      if (mounted) {
        setState(() {
          _failedQueueItems = queue is List ? queue : [];
        });
      }
    } catch (e) {
      print('Error loading failed queue: $e');
    }
  }

  Future<void> _checkStatus() async {
    try {
      final isRunning = await platform.invokeMethod('isServiceRunning');
      final hasPermission = await platform.invokeMethod('checkNotificationPermission');
      
      if (mounted) {
        setState(() {
          _isServiceRunning = isRunning ?? false;
          _hasPermission = hasPermission ?? false;
        });
      }
    } catch (e) {
      print('Error checking status: $e');
    }
  }

  Future<void> _sendTestNotification() async {
    final message = _testMessageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 메시지를 입력하세요')),
      );
      return;
    }

    try {
      await platform.invokeMethod('sendTestWebhook', {'message': message});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('테스트 알림을 전송했습니다'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('테스트 실패: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('알림 파싱 테스트'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
              onPressed: _toggleAutoRefresh,
              tooltip: _autoRefresh ? '자동 새로고침 정지' : '자동 새로고침 시작',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllData,
              tooltip: '수동 새로고침',
            ),
            IconButton(
              icon: const Icon(Icons.article),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LogViewerScreen(),
                  ),
                );
              },
              tooltip: '시스템 로그',
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.health_and_safety), text: '상태'),
              Tab(icon: Icon(Icons.list_alt), text: '로그'),
              Tab(icon: Icon(Icons.bug_report), text: '테스트'),
              Tab(icon: Icon(Icons.queue), text: '큐'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatusTab(),
            _buildLogsTab(),
            _buildTestTab(),
            _buildQueueTab(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 서비스 상태 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NotificationService 상태',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusRow('알림 접근 권한', _hasPermission),
                  const SizedBox(height: 8),
                  _buildStatusRow('서비스 실행 중', _isServiceRunning),
                  if (_serviceHealth != null) ...[
                    const SizedBox(height: 8),
                    _buildStatusRow('접근성 서비스', _serviceHealth!['isAccessibilityEnabled'] ?? false),
                    const SizedBox(height: 8),
                    _buildStatusRow('서비스 정상', _serviceHealth!['isHealthy'] ?? false),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 상세 정보 카드
          if (_serviceHealth != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상세 정보',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('큐 크기', '${_serviceHealth!['queueSize']} 개'),
                    _buildInfoRow('마지막 헬스체크', _formatTimestamp(_serviceHealth!['lastHealthCheck'])),
                    _buildInfoRow('마지막 알림', _formatTimestamp(_serviceHealth!['lastNotificationTime'])),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildLogsTab() {
    return Column(
      children: [
        // 상단 정보
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Text(
            '최근 파싱 로그 (${_recentLogs.length}개)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // 로그 리스트
        Expanded(
          child: _recentLogs.isEmpty
              ? const Center(child: Text('로그가 없습니다'))
              : ListView.builder(
                  itemCount: _recentLogs.length,
                  itemBuilder: (context, index) {
                    final log = _recentLogs[index];
                    return _buildLogItem(log);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 테스트 메시지 입력
          TextField(
            controller: _testMessageController,
            decoration: InputDecoration(
              labelText: '테스트 메시지',
              hintText: '예: 홍길동(홍*동)님이 50,000원을 보냈어요.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _testMessageController.clear(),
              ),
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 16),
          
          // 테스트 버튼들
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sendTestNotification,
                  icon: const Icon(Icons.send),
                  label: const Text('테스트 알림 전송'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQueueTab() {
    return Column(
      children: [
        // 상단 정보
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '실패 큐 (${_failedQueueItems.length}개)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_failedQueueItems.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final provider = Provider.of<NotificationProvider>(context, listen: false);
                    await provider.retrySendingFailedNotifications();
                    await _loadFailedQueue();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('재전송 시작')),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('재전송'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
        ),
        
        // 큐 리스트
        Expanded(
          child: _failedQueueItems.isEmpty
              ? const Center(child: Text('실패한 알림이 없습니다'))
              : ListView.builder(
                  itemCount: _failedQueueItems.length,
                  itemBuilder: (context, index) {
                    final item = _failedQueueItems[index];
                    return _buildQueueItem(item);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildLogItem(Map<String, dynamic> log) {
    final type = log['type'] ?? 'UNKNOWN';
    final timestamp = log['timestamp'] ?? 0;
    final message = log['message'] ?? '';
    
    Color typeColor = Colors.grey;
    if (type.contains('SUCCESS')) typeColor = Colors.green;
    else if (type.contains('ERROR') || type.contains('FAILED')) typeColor = Colors.red;
    else if (type.contains('PARSE')) typeColor = Colors.blue;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.2),
          child: Icon(
            type.contains('SUCCESS') ? Icons.check : 
            type.contains('ERROR') ? Icons.error : Icons.info,
            color: typeColor,
            size: 16,
          ),
        ),
        title: Text(
          type,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: typeColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        dense: true,
      ),
    );
  }
  
  Widget _buildQueueItem(Map<String, dynamic> item) {
    final id = item['id'] ?? '';
    final message = item['message'] ?? '';
    final retryCount = item['retryCount'] ?? 0;
    final timestamp = item['timestamp'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: Text(
            '$retryCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        title: Text(
          'ID: $id',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '재시도: $retryCount회 • ${_formatTimestamp(timestamp)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        dense: true,
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
          style: const TextStyle(fontSize: 14),
        ),
        const Spacer(),
        Text(
          status ? '활성화' : '비활성화',
          style: TextStyle(
            color: status ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return '없음';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return DateTimeUtils.getKSTDateString(date);
  }
}