import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/services/api_service_new.dart';
import 'package:remocall_flutter/services/database_service.dart';
import 'package:remocall_flutter/utils/type_utils.dart';

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
  
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  double get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _currentPage <= _totalPages;
  Map<String, dynamic>? get dashboardData => _dashboardData;
  
  Future<void> loadTransactions(String token, {bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    
    if (refresh) {
      _currentPage = 1;
      _totalPages = 1;
    }
    
    if (_currentPage > _totalPages) return;
    
    _setLoading(true);
    
    try {
      // 거래 내역과 잔액을 동시에 불러오기
      final results = await Future.wait([
        _apiService.getTransactions(
          token: token,
          page: _currentPage,
          limit: 20,
        ),
        _apiService.getBalance(token),
      ]);
      
      final transactionsResponse = results[0];
      final balanceResponse = results[1];
      
      // 잔액 업데이트
      if (balanceResponse['success']) {
        _balance = TypeUtils.safeToDouble(balanceResponse['data']['balance']);
      }
      
      // 거래 내역 처리
      if (transactionsResponse['success']) {
        final transactionsData = transactionsResponse['data']['transactions'] as List<dynamic>;
        final pagination = transactionsResponse['data']['pagination'];
        
        // Convert API transactions to our model
        final newTransactions = transactionsData.map((transaction) {
          // API의 status 값을 TransactionStatus enum으로 변환
          TransactionStatus status;
          switch (transaction['status']) {
            case 'pending':
              status = TransactionStatus.pending;
              break;
            case 'failed':
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
            amount: TypeUtils.safeToDouble(transaction['amount']),
            description: transaction['transaction_id'] ?? '',
            sender: transaction['payment_method'] ?? 'kakaopay_qr',
            category: 'payment', // 카테고리는 결제로 고정
            createdAt: DateTime.parse(transaction['created_at']),
            status: status,
            account: 'KakaoPay',
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
          }
        }
        
        _totalPages = pagination['totalPages'] ?? 1;
        _currentPage = pagination['currentPage'] ?? 1;
        if (refresh) {
          _currentPage++;
        }
        
        _error = null;
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
  
  Future<void> loadDashboard(String token) async {
    try {
      final response = await _apiService.getDashboard(token);
      
      if (response['success']) {
        _dashboardData = response['data'];
        notifyListeners();
      }
    } catch (e) {
      print('Error loading dashboard: $e');
    }
  }
  
  Future<void> loadBalance(String token) async {
    try {
      final response = await _apiService.getBalance(token);
      
      if (response['success']) {
        _balance = TypeUtils.safeToDouble(response['data']['balance']);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading balance: $e');
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