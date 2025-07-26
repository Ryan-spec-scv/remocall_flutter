// Stub functions for platforms that don't support workmanager

void callbackDispatcher() {
  // No-op for non-Android platforms
}

class WorkmanagerStub {
  Future<void> initialize(Function callback, {bool? isInDebugMode}) async {
    // No-op
  }
  
  Future<void> executeTask(Function(String, Map<String, dynamic>?) callback) async {
    // No-op
    return callback('', null);
  }
  
  Future<void> cancelAll() async {
    // No-op
  }
}

WorkmanagerStub Workmanager() => WorkmanagerStub();