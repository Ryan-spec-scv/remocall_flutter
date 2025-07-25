import 'package:flutter/foundation.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:remocall_flutter/services/database_service.dart';

class TransactionProvider extends ChangeNotifier {
  final List<TransactionModel> _transactions = [];
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMore => _currentPage < _totalPages;
  
  // 통계 정보
  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);
      
  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);
      
  double get balance => totalIncome - totalExpense;

  Future<void> loadTransactions(String token, {bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _transactions.clear();
    }
    
    _setLoading(true);
    
    try {
      // Load from local database first
      if (_currentPage == 1) {
        final localTransactions = await _databaseService.getTransactions();
        _transactions.addAll(localTransactions);
        notifyListeners();
      }
      
      // Then fetch from API
      final response = await _apiService.getTransactions(
        token: token,
        page: _currentPage,
      );
      
      if (response['success']) {
        final List<dynamic> transactionData = response['transactions'];
        final newTransactions = transactionData
            .map((json) => TransactionModel.fromJson(json))
            .toList();
        
        if (refresh) {
          _transactions.clear();
        }
        
        _transactions.addAll(newTransactions);
        _totalPages = response['totalPages'];
        _currentPage++;
        
        // Save to local database
        for (final transaction in newTransactions) {
          await _databaseService.insertTransaction(transaction);
        }
        
        _error = null;
      } else {
        _error = response['message'];
      }
    } catch (e) {
      _error = '거래내역을 불러오는데 실패했습니다';
      print('Error loading transactions: $e');
    } finally {
      _setLoading(false);
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
        category: _determineCategory(parsedData['type']),
        createdAt: DateTime.now(),
        account: parsedData['account'],
        balance: double.tryParse(parsedData['balance'] ?? '0'),
        rawMessage: parsedData['rawText'],
      );
      
      final id = await _databaseService.insertTransaction(transaction);
      final savedTransaction = transaction.copyWith(id: id.toString());
      
      _transactions.insert(0, savedTransaction);
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
      default:
        return TransactionType.unknown;
    }
  }

  String _determineCategory(String? type) {
    switch (type) {
      case 'income':
        return '수입';
      case 'expense':
        return '지출';
      case 'transfer':
        return '이체';
      case 'payment':
        return '결제';
      case 'cancel':
        return '취소';
      default:
        return '기타';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}