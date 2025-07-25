import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class APKUpdateService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  // 서버 URL
  static const String _serverUrl = 'https://yourserver.com';
  
  /// APK 파일을 다운로드하고 버전을 확인하는 방법
  Future<UpdateInfo?> checkForUpdateByDownloadingAPK() async {
    try {
      // 1. 현재 앱 버전
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      print('Current app version: $currentVersion');
      
      // 2. APK 파일의 헤더만 다운로드해서 크기 확인
      final headResponse = await _dio.head('$_serverUrl/latest.apk');
      final fileSize = headResponse.headers.value('content-length');
      
      print('APK file size: $fileSize bytes');
      
      // 3. 작은 부분만 다운로드해서 버전 확인 (실제로는 전체를 다운로드해야 함)
      // 여기서는 서버에서 APK 정보를 제공하는 API를 호출
      final response = await _dio.get('$_serverUrl/apk-info');
      
      if (response.statusCode == 200) {
        final latestVersion = response.data['version'];
        
        if (_isNewerVersion(currentVersion, latestVersion)) {
          return UpdateInfo(
            version: latestVersion,
            downloadUrl: '$_serverUrl/latest.apk',
            fileSize: int.tryParse(fileSize ?? '0') ?? 0,
            releaseNotes: response.data['releaseNotes'] ?? '',
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error checking for update: $e');
      return null;
    }
  }
  
  /// 서버에 APK 파일명 규칙이 있는 경우
  Future<UpdateInfo?> checkForUpdateByFileName() async {
    try {
      // 1. 현재 앱 버전
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 2. 서버의 파일 목록 가져오기
      final response = await _dio.get('$_serverUrl/apk-list');
      
      if (response.statusCode == 200) {
        final files = response.data['files'] as List;
        
        // 3. 파일명에서 버전 추출 (예: app-release-1.0.2.apk)
        String? latestVersion;
        String? latestFile;
        
        for (final file in files) {
          final match = RegExp(r'app-release-(\d+\.\d+\.\d+)\.apk').firstMatch(file);
          if (match != null) {
            final version = match.group(1)!;
            if (latestVersion == null || _isNewerVersion(latestVersion, version)) {
              latestVersion = version;
              latestFile = file;
            }
          }
        }
        
        if (latestVersion != null && _isNewerVersion(currentVersion, latestVersion)) {
          return UpdateInfo(
            version: latestVersion,
            downloadUrl: '$_serverUrl/$latestFile',
            fileSize: 0,
            releaseNotes: '새로운 업데이트가 있습니다.',
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error checking for update: $e');
      return null;
    }
  }
  
  /// 실제 APK 다운로드 및 설치
  Future<void> downloadAndInstallUpdate({
    required String downloadUrl,
    required Function(double) onProgress,
    required BuildContext context,
  }) async {
    try {
      // 권한 확인
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          throw Exception('설치 권한이 필요합니다');
        }
      }
      
      // 다운로드 디렉토리
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';
      
      // 기존 파일 삭제
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // APK 다운로드
      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );
      
      // APK 설치
      await OpenFile.open(filePath);
      
    } catch (e) {
      print('Error downloading/installing update: $e');
      rethrow;
    }
  }
  
  bool _isNewerVersion(String currentVersion, String newVersion) {
    try {
      final current = currentVersion.split('.').map((e) => int.parse(e)).toList();
      final latest = newVersion.split('.').map((e) => int.parse(e)).toList();
      
      for (int i = 0; i < latest.length; i++) {
        if (i >= current.length) return true;
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      
      return false;
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }
}

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final int fileSize;
  final String releaseNotes;
  
  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.fileSize,
    required this.releaseNotes,
  });
}