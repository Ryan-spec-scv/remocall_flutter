import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _changelog;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    // 패키지 정보
    final packageInfo = await PackageInfo.fromPlatform();
    
    // CHANGELOG 읽기
    String changelog = '';
    try {
      changelog = await rootBundle.loadString('CHANGELOG.md');
    } catch (e) {
      changelog = '변경 내역을 불러올 수 없습니다.';
    }

    setState(() {
      _packageInfo = packageInfo;
      _changelog = changelog;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 정보'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SnapPay',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('버전: ${_packageInfo?.version ?? '-'}'),
                    Text('빌드 번호: ${_packageInfo?.buildNumber ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '변경 내역',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_changelog ?? '로딩 중...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}