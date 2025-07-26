import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:remocall_flutter/services/database_service.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';

class TransactionProvider extends ChangeNotifier {
  final List<TransactionModel> _transactions = [];
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();
  
  double _balance = 0;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  
  // Dashboard data
  Map<String, dynamic>? _dashboardData;
  
  // Recent transactions from initial API (for home screen)
  List<TransactionModel> _recentTransactions = [];
  
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<TransactionModel> get recentTransactions => List.unmodifiable(_recentTransactions);
  double get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _currentPage <= _totalPages;
  Map<String, dynamic>? get dashboardData => _dashboardData;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  
  Future<void> loadTransactions(String token, {bool refresh = false, int? page}) async {
    if (_isLoading && !refresh) return;
    
    // 페이지 지정이 있으면 해당 페이지로, refresh만 있으면 1페이지로
    if (page != null) {
      _currentPage = page;
    } else if (refresh) {
      _currentPage = 1;
      _totalPages = 1;
    }
    
    if (_currentPage > _totalPages) return;
    
    _setLoading(true);
    
    try {
      print('[TransactionProvider] Loading page $_currentPage...');
      // 거래 내역만 불러오기 (잔액은 대시보드에서 관리)
      final transactionsResponse = await _apiService.getTransactions(
        token: token,
        page: _currentPage,
        limit: 20,
      );
      
      // 거래 내역 처리
      print('Transactions Response: $transactionsResponse');
      if (transactionsResponse['success'] == true) {
        final data = transactionsResponse['data'] ?? {};
        final transactionsData = data['transactions'] as List<dynamic>? ?? [];
        final pagination = data['pagination'] ?? {};
        print('[TransactionProvider] API returned ${transactionsData.length} transactions, refresh: $refresh, page: $_currentPage/$_totalPages');
        
        // Convert API transactions to our model
        final newTransactions = transactionsData.map((transaction) {
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
            type: TransactionType.income, // 모든 거래는 입금으로 처리
            amount: double.parse(transaction['amount'] ?? '0'),
            description: transaction['qr_code'] ?? '',
            sender: transaction['depositor_name'] ?? '알 수 없음',
            category: 'payment', // 카테고리는 결제로 고정
            createdAt: DateTimeUtils.parseToKST(transaction['created_at']),
            status: status,
            account: 'KakaoPay QR',
          );
        }).toList();
        
        if (refresh) {
          _transactions.clear();
          _transactions.addAll(newTransactions);
        } else {
          // 백그라운드 업데이트 시 중복 제거하고 새 트랜잭션만 추가
          final existingIds = _transactions.map((t) => t.id).toSet();
          final uniqueNewTransactions = newTransactions
              .where((t) => !existingIds.contains(t.id))
              .toList();
          
          if (uniqueNewTransactions.isNotEmpty) {
            // 새 트랜잭션을 앞에 추가하고 정렬
            _transactions.insertAll(0, uniqueNewTransactions);
            _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            print('[TransactionProvider] Added ${uniqueNewTransactions.length} new transactions');
          } else {
            print('[TransactionProvider] No new transactions found in background update');
          }
        }
        
        _totalPages = pagination['total_pages'] ?? 1;
        
        // 페이지 정보 업데이트 (refresh 시에는 서버에서 받은 값 그대로 사용)
        if (refresh) {
          _currentPage = pagination['current_page'] ?? 1;
        }
        
        _error = null;
        
        // 백그라운드 갱신 시에도 UI 업데이트를 위해 notifyListeners 호출
        if (!refresh) {
          notifyListeners();
        }
      } else {
        _error = transactionsResponse['message'];
      }
    } catch (e) {
      _error = '데이터를 불러오는데 실패했습니다';
      print('Error loading data: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 모든 거래내역을 한번에 로드하는 메서드
  Future<void> loadAllTransactions(String token) async {
    if (_isLoading) return;
    
    _setLoading(true);
    _transactions.clear();
    
    try {
      int currentPage = 1;
      int totalPages = 1;
      
      // 모든 페이지의 데이터를 가져올 때까지 반복
      while (currentPage <= totalPages) {
        print('[TransactionProvider] Loading all transactions - page $currentPage of $totalPages...');
        
        final transactionsResponse = await _apiService.getTransactions(
          token: token,
          page: currentPage,
          limit: 100, // 한 번에 더 많이 가져오도록 증가
        );
        
        if (transactionsResponse['success'] == true) {
          final data = transactionsResponse['data'] ?? {};
          final transactionsData = data['transactions'] as List<dynamic>? ?? [];
          final pagination = data['pagination'] ?? {};
          
          totalPages = pagination['total_pages'] ?? 1;
          
          // Convert API transactions to our model
          final newTransactions = transactionsData.map((transaction) {
            TransactionStatus status;
            String statusString = transaction['status'] ?? 'completed';
            
            switch (statusString) {
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
              id: transaction['id']?.toString(),
              type: TransactionType.income,
              amount: double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0,
              description: transaction['qr_code'] ?? '',
              sender: transaction['depositor_name'],
              category: '입금',
              createdAt: DateTimeUtils.parseToKST(transaction['created_at']),
              status: status,
            );
          }).toList();
          
          _transactions.addAll(newTransactions);
          currentPage++;
        } else {
          _error = transactionsResponse['message'];
          break;
        }
      }
      
      // 날짜순으로 정렬 (최신순)
      _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('[TransactionProvider] Total loaded transactions: ${_transactions.length}');
      _error = null;
      
    } catch (e) {
      _error = '데이터를 불러오는데 실패했습니다';
      print('Error loading all transactions: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> loadDashboard(String token) async {
    try {
      print('===== TransactionProvider.loadDashboard START =====');
      // 통합 API 사용
      final response = await _apiService.getInitialData(token);
      print('API Response: $response');
      
      // success 체크를 더 유연하게 처리
      if (response['success'] == true && response['data'] != null) {
        // 명시적으로 Map<String, dynamic>으로 변환
        final data = response['data'];
        print('Response data: $data');
        
        // 새로운 API 구조에 맞게 대시보드 데이터 구성
        _dashboardData = {
          'shop': data['shop'],
          'unsettled_fee': {
            'total_amount': data['unsettled']?['amount'] ?? 0,
            'last_updated': data['unsettled']?['last_updated'],
          },
          'today_stats': {
            'amount': data['today']?['amount'] ?? 0,
            'count': data['today']?['count'] ?? 0,
            'fee': data['today']?['fee'] ?? 0,
            'pending_count': data['today']?['pending_count'] ?? 0,
          },
          'total_stats': data['total'],
          'monthly_stats': data['this_month'],
        };
        print('Dashboard data set: $_dashboardData');
        
        // 미정산금 정보 업데이트
        final unsettledAmount = data['unsettled']?['amount'];
        if (unsettledAmount != null) {
          _balance = (unsettledAmount as num).toDouble();
          print('Balance updated: $_balance');
        }
        
        // recent_transactions 처리 (메인화면용)
        final recentTransactionsData = data['recent_transactions'] as List<dynamic>? ?? [];
        _recentTransactions = recentTransactionsData.map((transaction) {
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
        
        print('Recent transactions updated: ${_recentTransactions.length} items');
        
        print('Calling notifyListeners()');
        notifyListeners();
        print('===== TransactionProvider.loadDashboard END =====');
      } else {
        print('Response not successful or data is null');
        print('success: ${response['success']}, data: ${response['data']}');
      }
    } catch (e) {
      print('Error loading dashboard: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }
  
  Future<void> loadRealtimeData(String token) async {
    try {
      print('===== TransactionProvider.loadRealtimeData START =====');
      final response = await _apiService.getRealTimeData(token);
      print('Realtime API Response: $response');
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        
        // 실시간 데이터로 대시보드 정보 업데이트 (realtime API는 필드명이 다름)
        if (_dashboardData != null) {
          _dashboardData!['today_stats'] = data['today'];
          _dashboardData!['total_stats'] = data['total'];
          _dashboardData!['monthly_stats'] = data['this_month'];
          _dashboardData!['unsettled_fee'] = {
            'total_amount': data['unsettled']?['amount'] ?? 0,
            'last_updated': data['updated_at']
          };
        }
        
        // 잔액 업데이트
        final unsettledFee = data['unsettled']?['amount'] ?? 0;
        _balance = unsettledFee is int ? unsettledFee.toDouble() : double.tryParse(unsettledFee.toString()) ?? 0.0;
        
        print('Realtime data updated');
        notifyListeners();
        print('===== TransactionProvider.loadRealtimeData END =====');
      }
    } catch (e) {
      print('Error loading realtime data: $e');
    }
  }
  
  Future<void> loadMoreTransactions(String token) async {
    if (!hasMore || _isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.getTransactions(
        token: token,
        page: _currentPage,
        limit: 20,
      );
      
      if (response['success']) {
        final data = response['data'];
        final transactionsData = data['transactions'] as List;
        final newTransactions = transactionsData
            .map((json) => TransactionModel.fromJson(json))
            .toList();
        
        // Add new transactions to existing list
        _transactions.addAll(newTransactions);
        
        final pagination = data['pagination'] ?? {};
        _totalPages = pagination['total_pages'] ?? 1;
        _currentPage = pagination['current_page'] ?? 1;
        _currentPage++; // Increment for next page
      }
    } catch (e) {
      print('Error loading more transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  

  Future<void> addTransactionFromNotification(Map<String, dynamic> parsedData) async {
    try {
      final transaction = TransactionModel(
        type: _parseTransactionType(parsedData['type']),
        amount: double.tryParse(parsedData['amount'] ?? '0') ?? 0,
        description: parsedData['rawText'] ?? '',
        sender: parsedData['from'],
        receiver: parsedData['to'],
        category: 'notification', // 알림에서 추가된 거래
        createdAt: DateTime.now(),
        account: parsedData['account'],
        balance: double.tryParse(parsedData['balance'] ?? '0'),
        rawMessage: parsedData['rawText'],
      );
      
      // Add to local database
      await _databaseService.insertTransaction(transaction);
      
      // Add to list
      _transactions.insert(0, transaction);
      
      // Update balance if provided
      if (transaction.balance != null) {
        _balance = transaction.balance!;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error adding transaction from notification: $e');
    }
  }
  
  TransactionType _parseTransactionType(String? type) {
    switch (type) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      case 'payment':
        return TransactionType.payment;
      case 'cancel':
        return TransactionType.cancel;
      default:
        return TransactionType.unknown;
    }
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}