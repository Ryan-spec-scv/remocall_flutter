import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:remocall_flutter/widgets/transaction_list_item.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
  
  // 필터 상태
  TransactionStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPeriod = 'all'; // 'all', 'month', 'week', 'today'
  
  // 서버 페이지네이션
  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = 20;
  List<TransactionModel> _transactions = [];
  
  bool _isLoadingMore = false;
  // Timer? _refreshTimer; // 자동 갱신 제거됨
  
  @override
  void initState() {
    super.initState();
    print('[TransactionsScreen] initState called');
    _selectedStatus = TransactionStatus.completed; // 기본값을 '완료'로 설정
    _updateDateRangeForPeriod();
    _loadTransactions();
    
    // 자동 갱신 제거 - 수동 새로고침만 사용
  }
  
  @override
  void dispose() {
    // _refreshTimer?.cancel(); // 자동 갱신 제거됨
    super.dispose();
  }
  
  
  Future<void> _loadTransactions({int? page}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.accessToken != null) {
      setState(() {
        _isLoadingMore = true;
      });
      
      try {
        final apiService = ApiService();
        
        print('[TransactionsScreen] Loading transactions with filters:');
        print('  - page: ${page ?? _currentPage}');
        print('  - status: ${_selectedStatus?.toString().split('.').last}');
        print('  - startDate: ${_startDate != null ? dateFormatter.format(_startDate!) : null}');
        print('  - endDate: ${_endDate != null ? dateFormatter.format(_endDate!) : null}');
        print('  - selectedPeriod: $_selectedPeriod');
        
        final response = await apiService.getTransactions(
          token: authProvider.accessToken!,
          page: page ?? _currentPage,
          limit: _itemsPerPage,
          status: _selectedStatus?.toString().split('.').last,
          startDate: _startDate != null ? dateFormatter.format(_startDate!) : null,
          endDate: _endDate != null ? dateFormatter.format(_endDate!) : null,
        );
        
        if (response['success'] == true) {
          final data = response['data'] ?? {};
          final transactionsData = data['transactions'] as List<dynamic>? ?? [];
          final pagination = data['pagination'] ?? {};
          
          print('[TransactionsScreen] API Response - transactions count: ${transactionsData.length}');
          print('[TransactionsScreen] Pagination info: ${pagination}');
          print('[TransactionsScreen] - current_page: ${pagination['current_page']}');
          print('[TransactionsScreen] - total_pages: ${pagination['total_pages']}');
          print('[TransactionsScreen] - total_items: ${pagination['total_items']}');
          print('[TransactionsScreen] - items_per_page: ${pagination['items_per_page']}');
          if (transactionsData.isNotEmpty) {
            print('[TransactionsScreen] First transaction date: ${transactionsData[0]['created_at']}');
            print('[TransactionsScreen] Last transaction date: ${transactionsData[transactionsData.length - 1]['created_at']}');
          }
          
          setState(() {
            // Convert API transactions to our model
            _transactions = transactionsData.map((transaction) {
              // API의 status 값을 TransactionStatus enum으로 변환
              TransactionStatus status;
              switch (transaction['status']) {
                case 'pending':
                case 'scanned':
                case 'payment_waiting':
                  status = TransactionStatus.pending;
                  break;
                case 'failed':
                case 'expired':
                  status = TransactionStatus.failed;
                  break;
                case 'cancelled':
                  status = TransactionStatus.cancelled;
                  break;
                case 'completed':
                default:
                  status = TransactionStatus.completed;
              }
              
              return TransactionModel(
                id: transaction['id'].toString(),
                type: TransactionType.income,
                amount: double.parse(transaction['amount'] ?? '0'),
                description: transaction['qr_code'] ?? '',
                sender: transaction['depositor_name'] ?? '알 수 없음',
                category: 'payment',
                createdAt: DateTimeUtils.parseToKST(transaction['created_at']),
                status: status,
                account: 'KakaoPay QR',
              );
            }).toList();
            
            // 페이지네이션 정보 업데이트 (서버 응답 사용)
            _currentPage = pagination['current_page'] ?? 1;
            _totalPages = pagination['total_pages'] ?? 1;
            _isLoadingMore = false;
          });
        }
      } catch (e) {
        print('[TransactionsScreen] Error loading transactions: $e');
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
  
  Future<void> _loadTransactionsBackground() async {
    // 백그라운드 갱신 시에도 현재 필터 유지
    await _loadTransactions(page: _currentPage);
  }
  
  void _applyFilters() {
    // 필터가 변경되면 첫 페이지부터 다시 로드
    _currentPage = 1;
    _loadTransactions(page: 1);
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardTheme.color,
              onSurface: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      print('[TransactionsScreen] Custom date range selected:');
      print('  - start: ${dateFormatter.format(picked.start)}');
      print('  - end: ${dateFormatter.format(picked.end)}');
      
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1; // 필터 변경 시 첫 페이지로 이동
        _selectedPeriod = 'all'; // 커스텀 날짜 선택시 전체로 변경
      });
      // 날짜가 변경되어도 서버에서 다시 로드 (현재는 클라이언트 필터링만 적용)
      _applyFilters();
    }
  }
  
  void _clearFilters() {
    setState(() {
      _selectedStatus = TransactionStatus.completed;
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
      _selectedPeriod = 'all';
    });
    _applyFilters();
  }
  
  void _updateDateRangeForPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedPeriod) {
      case 'today':
        _startDate = today;
        _endDate = today;
        break;
      case 'week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        _startDate = weekStart;
        _endDate = today;
        break;
      case 'month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = today;
        break;
      case 'all':
      default:
        _startDate = null;
        _endDate = null;
        break;
    }
    
    print('[TransactionsScreen] Period: $_selectedPeriod');
    print('[TransactionsScreen] StartDate: ${_startDate != null ? dateFormatter.format(_startDate!) : "null"}');
    print('[TransactionsScreen] EndDate: ${_endDate != null ? dateFormatter.format(_endDate!) : "null"}');
  }
  
  void _onPeriodChanged(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
        _updateDateRangeForPeriod();
        _currentPage = 1;
      });
      _applyFilters();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 내역'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 필터 섹션
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기간 선택 탭
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildPeriodTab('all', '전체'),
                      _buildPeriodTab('month', '이번 달'),
                      _buildPeriodTab('week', '이번 주'),
                      _buildPeriodTab('today', '오늘'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 커스텀 날짜 필터 컨테이너 (애니메이션 처리)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _selectedPeriod == 'all' ? 48 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _selectedPeriod == 'all' ? 1.0 : 0.0,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectedPeriod == 'all' ? _selectDateRange : null,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _startDate != null && _endDate != null
                                  ? '${dateFormatter.format(_startDate!)} ~ ${dateFormatter.format(_endDate!)}'
                                  : '날짜 선택',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                        if (_startDate != null && _selectedPeriod == 'all')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _currentPage = 1;
                              });
                              _applyFilters();
                            },
                            child: const Text('날짜 초기화'),
                          ),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 거래 목록
          Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoadingMore && _transactions.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (_transactions.isEmpty && !_isLoadingMore) {
                    return Center(
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
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: () => _loadTransactions(page: 1),
                    displacement: 100,
                    backgroundColor: AppTheme.primaryColor,
                    color: Colors.white,
                    strokeWidth: 4,
                    child: ListView(
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
                        // 거래 목록
                        ..._transactions.map((transaction) => 
                          TransactionListItem(transaction: transaction)
                        ).toList(),
                        
                        // 서버 페이지네이션
                        if (_totalPages > 1)
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 이전 페이지 버튼
                                IconButton(
                                  onPressed: _currentPage > 1 && !_isLoadingMore
                                      ? () => _loadTransactions(page: _currentPage - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  color: AppTheme.primaryColor,
                                ),
                                
                                // 페이지 번호들
                                ..._buildPageNumbers(),
                                
                                // 다음 페이지 버튼
                                IconButton(
                                  onPressed: _currentPage < _totalPages && !_isLoadingMore
                                      ? () => _loadTransactions(page: _currentPage + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        
                        // 로딩 표시
                        if (_isLoadingMore)
                          Container(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  );
                }
              ),
            ),
          ],
        ),
    );
  }
  
  List<Widget> _buildPageNumbers() {
    List<Widget> pageButtons = [];
    
    // 표시할 페이지 범위 계산
    int startPage = ((_currentPage - 1) ~/ 5) * 5 + 1;
    int endPage = (startPage + 4).clamp(1, _totalPages);
    
    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextButton(
            onPressed: i != _currentPage && !_isLoadingMore
                ? () => _loadTransactions(page: i)
                : null,
            style: TextButton.styleFrom(
              backgroundColor: i == _currentPage
                  ? AppTheme.primaryColor
                  : Colors.transparent,
              foregroundColor: i == _currentPage
                  ? Colors.white
                  : AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: AppTheme.primaryColor,
                  width: i == _currentPage ? 0 : 1,
                ),
              ),
            ),
            child: Text(
              '$i',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    
    return pageButtons;
  }
  
  Widget _buildStatusFilterChip(TransactionStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    Color? statusColor;
    
    // 상태별 색상 설정
    if (status != null) {
      switch (status) {
        case TransactionStatus.completed:
          statusColor = Colors.green[700];
          break;
        case TransactionStatus.pending:
          statusColor = Colors.orange[700];
          break;
        case TransactionStatus.failed:
          statusColor = Colors.red[700];
          break;
        case TransactionStatus.cancelled:
          statusColor = Colors.grey[600];
          break;
        default:
          statusColor = null;
      }
    }
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        // '완료' 상태는 선택 해제할 수 없도록 처리
        if (status == TransactionStatus.completed && isSelected) {
          return; // 이미 선택된 '완료' 버튼을 다시 클릭하면 아무 동작 안함
        }
        
        setState(() {
          _selectedStatus = selected ? status : TransactionStatus.completed; // null 대신 완료로 기본값 설정
          _currentPage = 1; // 필터 변경 시 첫 페이지로 이동
        });
        
        // 클라이언트 측에서 필터링 적용
        _applyFilters();
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.5),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  Widget _buildPeriodTab(String period, String label) {
    final isSelected = _selectedPeriod == period;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPeriodChanged(period),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPeriodChip(String period, String label) {
    final isSelected = _selectedPeriod == period;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _onPeriodChanged(period);
        }
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.5),
        width: 1,
      ),
    );
  }
}