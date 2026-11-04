import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotifications {
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initializing;
  static bool get supported => !kIsWeb && [TargetPlatform.android,TargetPlatform.iOS].contains(defaultTargetPlatform);
  static Future<void> initialize() => _initializing ??= _initialize();
  static Future<void> _initialize() async {
    data.initializeTimeZones();
    await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)));
  }
  static Future<bool> schedule(int id, DateTime dueUtc) async {
    if (!supported || !dueUtc.isAfter(DateTime.now().toUtc())) return false;
    try {
      await initialize();
      final allowed = defaultTargetPlatform == TargetPlatform.android
        ? await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()
        : await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
      if (allowed != true) return false;
      await plugin.zonedSchedule(id + 1000, 'Khatabook follow-up', 'A follow-up is due. Open the app for details.',
        tz.TZDateTime.from(dueUtc, tz.getLocation('Asia/Kolkata')),
        const NotificationDetails(android: AndroidNotificationDetails('sss_followups', 'Follow-ups',
          channelDescription: 'Private follow-up reminders'), iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      return true;
    } catch (_) {return false;}
  }
  static Future<void> cancel(int id) async {
    if (!supported) return;
    try {await initialize(); await plugin.cancel(id + 1000);} catch (_) { /* In-app completion remains durable. */ }
  }
}
