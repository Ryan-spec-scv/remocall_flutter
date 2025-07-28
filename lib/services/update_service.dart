// Stub for macOS build
import 'package:flutter/material.dart';

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
  // Method matching the signature used in the code
  Future<UpdateInfo?> checkForUpdate({String? accessToken}) async {
    // No-op for macOS - return null to indicate no update available
    return null;
  }
  
  // Method matching the signature used in the code
  Future<void> downloadAndInstallUpdate({
    required String downloadUrl,
    required Function(double) onProgress,
    required BuildContext context,
  }) async {
    // No-op for macOS - just simulate completion
    await Future.delayed(Duration(milliseconds: 100));
    onProgress(1.0);
  }
  
  // Keep the old method for compatibility if needed
  Future<void> downloadAndInstallApk(UpdateInfo updateInfo) async {
    // No-op for macOS
  }
}
