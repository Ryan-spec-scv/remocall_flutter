import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SimpleUpdateChecker {
  static Future<bool> checkUpdate() async {
    try {
      // 1. 현재 앱 버전
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 2. 서버의 version.txt 파일 읽기
      final dio = Dio();
      final response = await dio.get(
        'https://yourserver.com/version.txt',
        options: Options(responseType: ResponseType.plain),
      );
      
      final latestVersion = response.data.toString().trim();
      
      // 3. 버전 비교
      return _compareVersions(currentVersion, latestVersion);
    } catch (e) {
      print('Update check failed: $e');
      return false;
    }
  }
  
  static bool _compareVersions(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    
    return false;
  }
}