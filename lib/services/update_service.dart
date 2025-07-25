import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:remocall_flutter/config/app_config.dart';

class UpdateService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  Future<UpdateInfo?> checkForUpdate({String? accessToken}) async {
    try {
      // 현재 앱 버전 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentVersionCode = _generateVersionCode(currentVersion);
      
      print('Current app version: $currentVersion (code: $currentVersionCode)');
      
      // 서버에서 최신 버전 정보 가져오기
      print('Checking for update at: ${AppConfig.updateUrl}/api/shop/app/version/check');
      final response = await _dio.post(
        '${AppConfig.updateUrl}/api/shop/app/version/check',
        data: {
          'current_version': currentVersion,
          'current_version_code': currentVersionCode,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      
      print('Server response status: ${response.statusCode}');
      print('Server response data: ${response.data}');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // API 응답 구조에 맞게 처리
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          final updateAvailable = data['update_available'] ?? false;
          final updateRequired = data['update_required'] ?? false;
          
          print('Update available: $updateAvailable, Required: $updateRequired');
          
          if (updateAvailable) {
            final latestVersion = data['latest_version'];
            final latestVersionCode = data['latest_version_code'];
            
            print('New version available: $latestVersion (code: $latestVersionCode)');
            
            return UpdateInfo(
              version: latestVersion,
              downloadUrl: data['download_url'],
              releaseNotes: data['release_notes'] ?? '새로운 업데이트가 있습니다.',
              isRequired: updateRequired,
            );
          } else {
            print('Already on latest version');
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error checking for update: $e');
      return null;
    }
  }
  
  Future<void> downloadAndInstallUpdate({
    required String downloadUrl,
    required Function(double) onProgress,
    required BuildContext context,
  }) async {
    // Windows에서는 업데이트 기능 비활성화
    if (!Platform.isAndroid) {
      throw Exception('업데이트는 Android에서만 지원됩니다');
    }
    
    try {
      // 권한 확인
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        throw Exception('설치 권한이 필요합니다');
      }
      
      // 다운로드 디렉토리 가져오기
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';
      
      // 기존 파일 삭제
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // APK 다운로드
      print('Starting download from: $downloadUrl');
      print('Saving to: $filePath');
      
      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            print('Download progress: ${(progress * 100).toStringAsFixed(1)}% ($received/$total)');
            onProgress(progress);
          } else {
            print('Unknown total size, received: $received bytes');
          }
        },
      );
      
      print('Download completed: $filePath');
      
      // APK 설치
      final result = await OpenFile.open(filePath);
      print('Install result: ${result.type} - ${result.message}');
      
    } catch (e) {
      print('Error downloading/installing update: $e');
      rethrow;
    }
  }
  
  bool _isNewerVersion(String currentVersion, String newVersion) {
    try {
      print('Version comparison: current=$currentVersion, new=$newVersion');
      final current = currentVersion.split('.').map((e) => int.parse(e)).toList();
      final latest = newVersion.split('.').map((e) => int.parse(e)).toList();
      
      print('Parsed versions: current=$current, latest=$latest');
      
      for (int i = 0; i < latest.length; i++) {
        if (i >= current.length) {
          print('New version has more segments');
          return true;
        }
        if (latest[i] > current[i]) {
          print('New version is higher at position $i: ${latest[i]} > ${current[i]}');
          return true;
        }
        if (latest[i] < current[i]) {
          print('Current version is higher at position $i: ${current[i]} > ${latest[i]}');
          return false;
        }
      }
      
      print('Versions are equal');
      return false;
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }
  
  // 버전 코드 생성 메소드
  int _generateVersionCode(String version) {
    try {
      final parts = version.split('.');
      if (parts.length != 3) {
        print('Invalid version format: $version');
        return 0;
      }
      
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final patch = int.parse(parts[2]);
      
      // 서버와 동일한 방식: major * 10000 + minor * 100 + patch
      final versionCode = major * 10000 + minor * 100 + patch;
      return versionCode;
    } catch (e) {
      print('Error generating version code: $e');
      return 0;
    }
  }
}

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool isRequired;
  
  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isRequired = false,
  });
}