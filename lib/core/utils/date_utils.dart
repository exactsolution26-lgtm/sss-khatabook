import 'package:intl/intl.dart';

class DateUtils {
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm:ss';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'dd MMM yyyy';

  static String formatDate(DateTime date) {
    return DateFormat(dateFormat).format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat(timeFormat).format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat(dateTimeFormat).format(date);
  }

  static String formatDisplayDate(DateTime date) {
    return DateFormat(displayDateFormat).format(date);
  }

  static DateTime parseDate(String dateString) {
    return DateFormat(dateFormat).parse(dateString);
  }

  static DateTime parseDateTime(String dateTimeString) {
    return DateFormat(dateTimeFormat).parse(dateTimeString);
  }

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool isToday(DateTime date) {
    final today = DateUtils.today();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
