import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:remocall_flutter/config/app_config.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final bool isForceUpdate;
  
  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.isForceUpdate,
  });
}

class UpdateService {
  final Dio _dio = Dio();

  Future<UpdateInfo?> checkForUpdate({String? accessToken}) async {
    try {
      // Get current app version info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      print('[UpdateService] Current version: $currentVersion (build: $currentBuildNumber)');
      
      // Prepare headers
      final headers = <String, dynamic>{
        'Content-Type': 'application/json',
      };
      
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      // Determine API URL
      final apiUrl = AppConfig.isProduction 
          ? 'https://admin-api.snappay.online' 
          : 'https://kakaopay-admin-api.flexteam.kr';
      
      print('[UpdateService] Checking for updates at: $apiUrl/api/shop/app/version/check');
      print('[UpdateService] Is production: ${AppConfig.isProduction}');

      // Make API call to check for updates
      final response = await _dio.post(
        '$apiUrl/api/shop/app/version/check',
        data: {
          'platform': 'android',
          'current_version': currentVersion,
          'current_version_code': currentBuildNumber,
        },
        options: Options(
          headers: headers,
          receiveTimeout: AppConfig.receiveTimeout,
          sendTimeout: AppConfig.connectionTimeout,
        ),
      );

      print('[UpdateService] Response status: ${response.statusCode}');
      print('[UpdateService] Response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        
        // API response structure: { success: bool, data: { update_available, latest_version, etc } }
        final responseData = data['data'] ?? data;
        final updateAvailable = responseData['update_available'] ?? false;
        
        if (updateAvailable) {
          // Parse the response from data object
          final latestVersion = responseData['latest_version'] ?? '';
          final latestVersionCode = responseData['latest_version_code'] ?? 0;
          final downloadUrl = responseData['download_url'] ?? '';
          final releaseNotes = responseData['release_notes'] ?? '';
          final isForceUpdate = responseData['update_required'] ?? false;
          
          print('[UpdateService] Update available: v$latestVersion (build: $latestVersionCode)');
          
          // Only return UpdateInfo if there's actually a newer version
          print('[UpdateService] Comparing versions: current=$currentBuildNumber, latest=$latestVersionCode');
          if (latestVersionCode > currentBuildNumber && downloadUrl.isNotEmpty) {
            return UpdateInfo(
              version: latestVersion,
              changelog: releaseNotes,
              downloadUrl: downloadUrl,
              isForceUpdate: isForceUpdate,
            );
          }
        } else {
          print('[UpdateService] No update available');
        }
      }
      
      return null; // No update available
    } catch (e) {
      print('[UpdateService] Error checking for update: $e');
      // Return null on error to avoid disrupting the app
      return null;
    }
  }
  
  Future<void> downloadAndInstallUpdate({
    required String downloadUrl,
    required Function(double) onProgress,
    required BuildContext context,
  }) async {
    if (!Platform.isAndroid) {
      print('[UpdateService] APK installation only supported on Android');
      return;
    }
    
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/update.apk';
      
      // Delete existing file if any
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      print('[UpdateService] Downloading APK from: $downloadUrl');
      
      // Download the APK
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
      
      print('[UpdateService] Download complete, installing APK...');
      
      // Install the APK
      await OpenFilex.open(filePath);
      
    } catch (e) {
      print('[UpdateService] Error downloading/installing update: $e');
      throw e;
    }
  }
}