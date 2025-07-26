// Stub for platforms that don't support open_filex and permission_handler

class OpenFilexStub {
  static Future<dynamic> open(String filePath) async {
    print('OpenFilex not supported on this platform');
    return null;
  }
}

class OpenFilex extends OpenFilexStub {}

class PermissionStub {
  static PermissionStub requestInstallPackages = PermissionStub();
  
  Future<PermissionStatus> request() async {
    return PermissionStatus.granted;
  }
}

class Permission extends PermissionStub {}

enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}