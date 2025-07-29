import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/screens/home/home_screen.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/providers/theme_provider.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopCodeController = TextEditingController();
  final _pinController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _shopCodeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithPin(
      _shopCodeController.text.trim().toUpperCase(),
      _pinController.text.trim().toUpperCase(),
    );
    
    setState(() {
      _isLoading = false;
    });
    
    if (success) {
      // Update NotificationProvider with shop code and access token
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.updateShopCode(_shopCodeController.text.trim().toUpperCase());
      notificationProvider.updateAccessToken(authProvider.accessToken);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? '로그인에 실패했습니다'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // 앱 이름
                  Text(
                    'SnapPay',
                    style: AppTheme.headlineLarge.copyWith(
                      color: isDarkMode ? AppTheme.primaryLight : AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '매장 관리 시스템',
                    style: AppTheme.bodyLarge.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // 매장 코드 입력
                  TextFormField(
                    controller: _shopCodeController,
                    decoration: InputDecoration(
                      labelText: '매장 코드',
                      hintText: '예: AB12',
                      prefixIcon: const Icon(Icons.store_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                    ),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '매장 코드를 입력해주세요';
                      }
                      if (value.length != 4) {
                        return '매장 코드는 4자리입니다';
                      }
                      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
                        return '매장 코드는 영문과 숫자만 가능합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // PIN 입력
                  TextFormField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      hintText: '6자리 영문+숫자',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePin = !_obscurePin;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                    ),
                    obscureText: _obscurePin,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'PIN을 입력해주세요';
                      }
                      if (value.length != 6) {
                        return 'PIN은 6자리입니다';
                      }
                      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
                        return 'PIN은 영문과 숫자만 가능합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? AppTheme.primaryLight : AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '로그인',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 도움말
                  Text(
                    'PIN을 모르시나요? 관리자에게 문의하세요.',
                    style: AppTheme.bodySmall.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}