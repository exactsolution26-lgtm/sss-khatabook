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
    return date.toUtc().toIso8601String();
  }

  static String formatDisplayDate(DateTime date) {
    return DateFormat(displayDateFormat).format(date);
  }

  static DateTime parseDate(String dateString) {
    return DateFormat(dateFormat).parse(dateString);
  }

  static DateTime parseDateTime(String dateTimeString) {
    // New records contain an explicit UTC offset; legacy SQLite rows use a
    // space-separated local timestamp. Dart supports both without discarding
    // the offset or interpreting an ISO 'T' as a formatting failure.
    final parsed = DateTime.tryParse(dateTimeString);
    if (parsed == null) throw FormatException('Invalid stored timestamp');
    return parsed;
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
