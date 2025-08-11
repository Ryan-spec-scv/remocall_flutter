import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/auth_provider.dart';
import 'package:remocall_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestTokenScreen extends StatefulWidget {
  const TestTokenScreen({Key? key}) : super(key: key);

  @override
  State<TestTokenScreen> createState() => _TestTokenScreenState();
}

class _TestTokenScreenState extends State<TestTokenScreen> {
  final ApiService _apiService = ApiService();
  String _testResult = '';
  String? _currentAccessToken;
  String? _currentRefreshToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTokens();
  }

  Future<void> _loadCurrentTokens() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 모든 가능한 키 확인
      _currentAccessToken = prefs.getString('flutter.access_token') ?? prefs.getString('access_token');
      _currentRefreshToken = prefs.getString('flutter.refresh_token') ?? prefs.getString('refresh_token');
      
      // 디버깅을 위한 로그
      print('[TestTokenScreen] Loaded tokens:');
      print('  - Access Token (flutter.): ${prefs.getString('flutter.access_token') != null}');
      print('  - Access Token (plain): ${prefs.getString('access_token') != null}');
      print('  - Refresh Token (flutter.): ${prefs.getString('flutter.refresh_token') != null}');
      print('  - Refresh Token (plain): ${prefs.getString('refresh_token') != null}');
    });
  }

  Future<void> _testTokenRefresh() async {
    setState(() {
      _isLoading = true;
      _testResult = '토큰 갱신 테스트 시작...\n';
    });

    if (_currentRefreshToken == null) {
      setState(() {
        _testResult += '❌ Refresh Token이 없습니다.\n';
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. 현재 토큰으로 API 테스트
      setState(() {
        _testResult += '\n1️⃣ 현재 토큰으로 API 호출 테스트...\n';
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.accessToken != null) {
        final testResponse = await _apiService.getRealTimeData(authProvider.accessToken!);
        if (testResponse['success'] == true) {
          setState(() {
            _testResult += '✅ 현재 토큰 유효함\n';
          });
        } else {
          setState(() {
            _testResult += '❌ 현재 토큰 무효: ${testResponse['message']}\n';
          });
        }
      }

      // 2. 토큰 갱신 테스트
      setState(() {
        _testResult += '\n2️⃣ 토큰 갱신 API 호출...\n';
        _testResult += '- Refresh Token 전송: ${_currentRefreshToken!.substring(0, 20)}...\n';
      });

      final refreshResponse = await _apiService.refreshToken(_currentRefreshToken!);
      
      setState(() {
        _testResult += '\n전체 응답:\n${refreshResponse.toString()}\n';
      });
      
      if (refreshResponse['success'] == true) {
        setState(() {
          _testResult += '✅ 토큰 갱신 성공!\n';
          
          final data = refreshResponse['data'];
          if (data != null) {
            final newAccessToken = data['access_token'];
            final newRefreshToken = data['refresh_token'];
            
            _testResult += '- 새 Access Token: ${newAccessToken != null ? '발급됨' : '없음'}\n';
            _testResult += '- 새 Refresh Token: ${newRefreshToken != null ? '발급됨' : '없음'}\n';
            
            if (newAccessToken == _currentAccessToken) {
              _testResult += '⚠️ Access Token이 동일함 (변경되지 않음)\n';
            } else {
              _testResult += '✅ Access Token이 변경됨\n';
            }
            
            if (newRefreshToken == _currentRefreshToken) {
              _testResult += '⚠️ Refresh Token이 동일함 (변경되지 않음)\n';
            } else {
              _testResult += '✅ Refresh Token이 변경됨\n';
            }
          }
        });

        // 3. 새 토큰으로 API 테스트
        setState(() {
          _testResult += '\n3️⃣ 새 토큰으로 API 호출 테스트...\n';
        });

        final newAccessToken = refreshResponse['data']['access_token'];
        if (newAccessToken != null) {
          final testResponse2 = await _apiService.getRealTimeData(newAccessToken);
          if (testResponse2['success'] == true) {
            setState(() {
              _testResult += '✅ 새 토큰으로 API 호출 성공\n';
            });
          } else {
            setState(() {
              _testResult += '❌ 새 토큰으로 API 호출 실패: ${testResponse2['message']}\n';
            });
          }
        }
      } else {
        setState(() {
          _testResult += '❌ 토큰 갱신 실패: ${refreshResponse['message']}\n';
        });
      }
    } catch (e) {
      setState(() {
        _testResult += '❌ 오류 발생: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      await _loadCurrentTokens();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('토큰 갱신 테스트'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '현재 토큰 정보',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Access Token: ${_currentAccessToken != null ? '있음' : '없음'}'),
                    if (_currentAccessToken != null)
                      Text('- 길이: ${_currentAccessToken!.length}자'),
                    const SizedBox(height: 4),
                    Text('Refresh Token: ${_currentRefreshToken != null ? '있음' : '없음'}'),
                    if (_currentRefreshToken != null)
                      Text('- 길이: ${_currentRefreshToken!.length}자'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testTokenRefresh,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isLoading ? '테스트 중...' : '토큰 갱신 테스트'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '테스트 결과',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _testResult.isEmpty ? '테스트를 실행하세요.' : _testResult,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}