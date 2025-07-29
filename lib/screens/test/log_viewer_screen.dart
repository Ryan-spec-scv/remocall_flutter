import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:intl/intl.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  static const platform = MethodChannel('com.remocall/notifications');
  List<dynamic> _logFiles = [];
  List<dynamic> _currentLogs = [];
  String? _selectedFile;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }
  
  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final String filesJson = await platform.invokeMethod('getLogFiles');
      final files = jsonDecode(filesJson);
      setState(() {
        _logFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading log files: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadLogContent(String fileName) async {
    setState(() {
      _isLoading = true;
      _selectedFile = fileName;
    });
    
    try {
      final String logsJson = await platform.invokeMethod('readLogFile', {'fileName': fileName});
      final logs = jsonDecode(logsJson);
      setState(() {
        _currentLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading log content: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _triggerUpload() async {
    try {
      await platform.invokeMethod('triggerLogUpload');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그 업로드가 시작되었습니다'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업로드 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  Color _getLogTypeColor(String type) {
    switch (type) {
      case 'SERVICE_LIFECYCLE':
        return Colors.blue;
      case 'NOTIFICATION_RECEIVED':
        return Colors.green;
      case 'PATTERN_FILTER':
        return Colors.orange;
      case 'SERVER_REQUEST':
        return Colors.purple;
      case 'FAILED_QUEUE':
        return Colors.red;
      case 'TOKEN_REFRESH':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
  
  String _getLogTypeIcon(String type) {
    switch (type) {
      case 'SERVICE_LIFECYCLE':
        return '🔄';
      case 'NOTIFICATION_RECEIVED':
        return '📱';
      case 'PATTERN_FILTER':
        return '🔍';
      case 'SERVER_REQUEST':
        return '🌐';
      case 'FAILED_QUEUE':
        return '❌';
      case 'TOKEN_REFRESH':
        return '🔐';
      default:
        return '📋';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('시스템 로그'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _triggerUpload,
            tooltip: '로그 업로드',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogFiles,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 파일 목록 (상단)
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.grey[100],
                  child: Row(
                    children: [
                      const Icon(Icons.folder, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '로그 파일 (${_logFiles.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading && _selectedFile == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _logFiles.length,
                          itemBuilder: (context, index) {
                            final file = _logFiles[index];
                            final isSelected = file['name'] == _selectedFile;
                            
                            return Card(
                              color: isSelected 
                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                  : null,
                              child: InkWell(
                                onTap: () => _loadLogContent(file['name']),
                                child: Container(
                                  width: 200,
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.insert_drive_file,
                                            size: 16,
                                            color: isSelected ? AppTheme.primaryColor : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              file['name'],
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : null,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_formatFileSize(file['size'])}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Text(
                                        DateTimeUtils.formatKST(
                                          DateTime.fromMillisecondsSinceEpoch(file['lastModified']),
                                          'MM/dd HH:mm',
                                        ),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // 로그 내용 (하단)
          Expanded(
            child: _selectedFile == null
                ? const Center(
                    child: Text(
                      '로그 파일을 선택하세요',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[850]
                            : Colors.grey[100],
                        child: Row(
                          children: [
                            const Icon(Icons.description, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _selectedFile!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_currentLogs.length} 항목',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _currentLogs.length,
                                itemBuilder: (context, index) {
                                  final log = _currentLogs[index];
                                  final type = log['type'] ?? 'UNKNOWN';
                                  final timestamp = log['timestamp'] ?? 0;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ExpansionTile(
                                      leading: Text(
                                        _getLogTypeIcon(type),
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getLogTypeColor(type).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              type,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _getLogTypeColor(type),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateTimeUtils.formatKST(
                                              DateTime.fromMillisecondsSinceEpoch(timestamp),
                                              'HH:mm:ss.SSS',
                                            ),
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      subtitle: _buildLogSummary(log),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: _buildLogDetails(log),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogSummary(Map<String, dynamic> log) {
    final type = log['type'] ?? 'UNKNOWN';
    String summary = '';
    
    switch (type) {
      case 'SERVICE_LIFECYCLE':
        summary = log['event'] ?? '';
        break;
      case 'NOTIFICATION_RECEIVED':
        final messageStr = log['message']?.toString() ?? '';
        if (messageStr.length > 50) {
          summary = messageStr.substring(0, 50) + '...';
        } else {
          summary = messageStr;
        }
        break;
      case 'PATTERN_FILTER':
        summary = '${log['isDeposit'] == true ? '입금 알림' : '일반 알림'} - ${log['reason']}';
        break;
      case 'SERVER_REQUEST':
        summary = '${log['responseCode']} ${log['success'] == true ? '성공' : '실패'}';
        break;
      case 'FAILED_QUEUE':
        summary = '${log['action']} - 재시도: ${log['retryCount']}회';
        break;
      case 'TOKEN_REFRESH':
        summary = log['success'] == true ? '토큰 갱신 성공' : '토큰 갱신 실패';
        break;
    }
    
    return Text(
      summary,
      style: const TextStyle(fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
  
  Widget _buildLogDetails(Map<String, dynamic> log) {
    final entries = log.entries.where((e) => e.key != 'type' && e.key != 'timestamp').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        String value = entry.value.toString();
        if (entry.value is Map || entry.value is List) {
          value = const JsonEncoder.withIndent('  ').convert(entry.value);
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}