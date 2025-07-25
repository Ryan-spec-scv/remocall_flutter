import 'package:intl/intl.dart';

/// Utility class for handling DateTime formatting
/// API에서 받은 시간을 그대로 표시하는 유틸리티
class DateTimeUtils {
  
  /// Parse a date string from API
  static DateTime parseToKST(String dateString) {
    // API에서 받은 시간 문자열을 직접 파싱
    // 2025-07-21T05:13:14+09:00 형식
    if (dateString.contains('+09:00')) {
      // +09:00을 제거하고 시간 부분만 추출
      final cleanString = dateString.substring(0, dateString.indexOf('+'));
      // 로컬 시간으로 파싱 (시간대 변환 없이)
      return DateTime.parse(cleanString);
    }
    
    return DateTime.parse(dateString);
  }
  
  /// Common date formatters
  static final DateFormat kstDateFormatter = DateFormat('yyyy년 MM월 dd일');
  static final DateFormat kstTimeFormatter = DateFormat('HH:mm:ss');
  static final DateFormat kstDateTimeFormatter = DateFormat('yyyy년 MM월 dd일 HH:mm:ss');
  static final DateFormat kstShortDateTimeFormatter = DateFormat('MM/dd HH:mm');
  static final DateFormat kstMonthDayFormatter = DateFormat('MM월 dd일');
  
  /// Get formatted date string
  static String getKSTDateString(DateTime dateTime) {
    return kstDateFormatter.format(dateTime);
  }
  
  /// Get formatted time string
  static String getKSTTimeString(DateTime dateTime) {
    return kstTimeFormatter.format(dateTime);
  }
  
  /// Get formatted date and time string
  static String getKSTDateTimeString(DateTime dateTime) {
    return kstDateTimeFormatter.format(dateTime);
  }
  
  /// Get short formatted date and time string (MM/dd HH:mm)
  static String getKSTShortDateTimeString(DateTime dateTime) {
    return kstShortDateTimeFormatter.format(dateTime);
  }
  
  /// Format DateTime with custom format
  static String formatKST(DateTime dateTime, String format) {
    final formatter = DateFormat(format);
    return formatter.format(dateTime);
  }
  
  /// Check if two dates are on the same day
  static bool isSameDayKST(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
  
  /// Get month and day string
  static String getMonthDayString(DateTime dateTime) {
    return kstMonthDayFormatter.format(dateTime);
  }
}