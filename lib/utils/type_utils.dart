/// 타입 변환 유틸리티
class TypeUtils {
  /// 안전한 double 변환
  /// null이거나 변환 실패 시 defaultValue 반환
  static double safeToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? defaultValue;
    }
    
    if (value is num) {
      return value.toDouble();
    }
    
    return defaultValue;
  }
  
  /// nullable double 변환
  /// 변환 실패 시 null 반환
  static double? safeToDoubleOrNull(dynamic value) {
    if (value == null) return null;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    
    if (value is String) {
      return double.tryParse(value);
    }
    
    if (value is num) {
      return value.toDouble();
    }
    
    return null;
  }
}