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

  static String formatIstDateTime(DateTime timestamp) {
    final ist = timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    String two(int value) => value.toString().padLeft(2, '0');
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    return '${days[ist.weekday - 1]}, ${ist.day} ${months[ist.month - 1]} ${ist.year} · '
        '${two(hour)}:${two(ist.minute)}:${two(ist.second)} ${ist.hour < 12 ? 'AM' : 'PM'} IST';
  }

  static DateTime indiaToday() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(ist.year, ist.month, ist.day);
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
