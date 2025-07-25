import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/providers/transaction_provider.dart';
import 'package:remocall_flutter/models/notification_model.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'dart:io';

class ManualDepositScreen extends StatefulWidget {
  const ManualDepositScreen({super.key});

  @override
  State<ManualDepositScreen> createState() => _ManualDepositScreenState();
}

class _ManualDepositScreenState extends State<ManualDepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senderController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isProcessing = false;
  File? _selectedImage;

  @override
  void dispose() {
    _senderController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      setState(() {
        _isProcessing = true;
        _selectedImage = File(image.path);
      });

      // OCR 처리 - ML Kit 제거로 임시 비활성화
      _showSnackBar('OCR 기능이 일시적으로 비활성화되었습니다. 직접 입력해주세요.');
    } catch (e) {
      _showSnackBar('이미지 처리 중 오류가 발생했습니다');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _parseKakaoPayMessage(String text) {
    // 보낸사람 파싱
    final senderPattern = RegExp(r'([가-힣a-zA-Z0-9]+)\([가-힣a-zA-Z0-9*]+\)님이');
    final senderMatch = senderPattern.firstMatch(text);
    if (senderMatch != null) {
      _senderController.text = senderMatch.group(1) ?? '';
    }

    // 금액 파싱
    final amountPattern = RegExp(r'([0-9,]+)원');
    final amountMatch = amountPattern.firstMatch(text);
    if (amountMatch != null) {
      final amount = amountMatch.group(1)?.replaceAll(',', '') ?? '';
      _amountController.text = amount;
    }
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<NotificationProvider>(context, listen: false);
    
    // 메시지 생성
    final message = '${_senderController.text}님이 ${_amountController.text}원을 보냈어요.';
    
    // 알림으로 추가
    final notification = NotificationModel(
      packageName: 'manual.input',
      sender: '수동입력',
      message: message,
      receivedAt: DateTime.now(),
      parsedData: {
        'type': 'income',
        'from': _senderController.text,
        'amount': _amountController.text,
      },
    );
    await provider.addNotification(notification);

    // 서버에서 처리할 시간을 주기 위해 잠시 대기
    await Future.delayed(const Duration(seconds: 2));

    // 트랜잭션 목록 강제 새로고침
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    if (authProvider.accessToken != null) {
      await transactionProvider.loadTransactions(authProvider.accessToken!, refresh: true);
    }

    _showSnackBar('입금 내역이 추가되었습니다');
    Navigator.pop(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('입금 수동 입력'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // iOS 안내 메시지
              if (Platform.isIOS)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(height: 8),
                      Text(
                        'iOS에서는 카카오페이 알림을 자동으로 읽을 수 없습니다.\n'
                        '스크린샷을 업로드하거나 직접 입력해주세요.',
                        style: TextStyle(color: Colors.blue[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // 스크린샷 업로드 버튼
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAndProcessImage,
                icon: const Icon(Icons.photo_library),
                label: Text(_isProcessing ? '처리 중...' : '카카오페이 스크린샷 업로드'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              
              if (_selectedImage != null) ...[
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              Text(
                '직접 입력',
                style: AppTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              // 보낸사람 입력
              TextFormField(
                controller: _senderController,
                decoration: const InputDecoration(
                  labelText: '보낸사람',
                  hintText: '예: 홍길동',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '보낸사람을 입력해주세요';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 금액 입력
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '금액',
                  hintText: '예: 10000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: '원',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '금액을 입력해주세요';
                  }
                  if (int.tryParse(value) == null) {
                    return '올바른 금액을 입력해주세요';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // 제출 버튼
              ElevatedButton(
                onPressed: _submitDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  '입금 내역 추가',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}