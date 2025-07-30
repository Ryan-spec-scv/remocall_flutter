import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:remocall_flutter/utils/type_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
  
  bool _isLoading = true;
  Map<String, dynamic>? _transactionDetail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactionDetail();
  }

  Future<void> _loadTransactionDetail() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      try {
        final apiService = ApiService();
        final response = await apiService.getTransactionDetail(
          token: authProvider.accessToken!,
          transactionId: int.parse(widget.transaction.id!),
        );
        
        if (response['success'] == true && mounted) {
          setState(() {
            // API 응답이 data.transaction 구조로 되어 있음
            _transactionDetail = response['data']['transaction'] ?? response['data'];
            _isLoading = false;
            
            // 디버그 로그
            print('===== Transaction Detail =====');
            print('Full response: $response');
            print('Transaction detail: $_transactionDetail');
            print('ID: ${_transactionDetail?['id']}');
            print('Depositor name: ${_transactionDetail?['depositor_name']}');
            print('Created at: ${_transactionDetail?['created_at']}');
            print('=============================');
          });
        } else if (mounted) {
          setState(() {
            _error = response['message'] ?? '거래 상세 정보를 불러올 수 없습니다';
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading transaction detail: $e');
        if (mounted) {
          setState(() {
            _error = '오류가 발생했습니다';
            _isLoading = false;
          });
        }
      }
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return AppTheme.successColor;
      case TransactionStatus.pending:
        return AppTheme.warningColor;
      case TransactionStatus.failed:
        return AppTheme.errorColor;
      case TransactionStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return '완료';
      case TransactionStatus.pending:
        return '대기중';
      case TransactionStatus.failed:
        return '만료';
      case TransactionStatus.cancelled:
        return '취소';
      default:
        return '알 수 없음';
    }
  }

  Future<void> _launchKakaoPayLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카카오페이 링크를 열 수 없습니다'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 상세'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadTransactionDetail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상태 카드
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.transaction.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getStatusColor(widget.transaction.status).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              widget.transaction.status == TransactionStatus.completed
                                  ? Icons.check_circle
                                  : widget.transaction.status == TransactionStatus.pending
                                      ? Icons.pending
                                      : Icons.cancel,
                              size: 48,
                              color: _getStatusColor(widget.transaction.status),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _getStatusText(widget.transaction.status),
                              style: AppTheme.headlineSmall.copyWith(
                                color: _getStatusColor(widget.transaction.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormatter.format(widget.transaction.amount),
                              style: AppTheme.headlineMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms),

                      const SizedBox(height: 24),

                      // 거래 정보
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
                              '거래 정보',
                              style: AppTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow('거래 ID', _transactionDetail?['id']?.toString() ?? '-'),
                            _buildDetailRow('상태', _getStatusText(widget.transaction.status)),
                            _buildDetailRow('금액', currencyFormatter.format(TypeUtils.safeToDouble(_transactionDetail?['amount']))),
                            _buildDetailRow('입금자명', _transactionDetail?['depositor_name'] ?? '알 수 없음'),
                            if (_transactionDetail?['qr_code'] != null && _transactionDetail!['qr_code'].toString().isNotEmpty)
                              _buildDetailRow('QR 코드', _transactionDetail!['qr_code']),
                            _buildDetailRow(
                              '생성일시',
                              _transactionDetail?['created_at'] != null
                                  ? DateTimeUtils.getKSTDateTimeString(DateTimeUtils.parseToKST(_transactionDetail!['created_at']))
                                  : '-',
                            ),
                            if (_transactionDetail?['completed_at'] != null)
                              _buildDetailRow(
                                '완료일시',
                                DateTimeUtils.getKSTDateTimeString(DateTimeUtils.parseToKST(_transactionDetail!['completed_at'])),
                              ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      // 카카오페이 QR 정보
                      if (_transactionDetail?['kakao_pay_qr'] != null) ...[
                        const SizedBox(height: 16),
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
                              Row(
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    color: AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '카카오페이 QR',
                                    style: AppTheme.headlineSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow('QR 이름', _transactionDetail!['kakao_pay_qr']['name'] ?? ''),
                              const SizedBox(height: 12),
                              if (_transactionDetail!['kakao_pay_qr']['kakao_pay_link'] != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final link = _transactionDetail!['kakao_pay_qr']['kakao_pay_link'];
                                      Clipboard.setData(ClipboardData(text: link));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('링크가 클립보드에 복사되었습니다'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: AppTheme.primaryColor,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy),
                                    label: const Text('링크 복사'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      side: const BorderSide(color: AppTheme.primaryColor),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],

                      const SizedBox(height: 24),

                      // 뒤로가기 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
}