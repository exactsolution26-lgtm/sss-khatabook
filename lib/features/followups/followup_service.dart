import '../../database/db_helper.dart';
import 'reminder_notifications.dart';

class FollowupService {
  FollowupService({Future<bool> Function(int,DateTime)? schedule, Future<void> Function(int)? cancel})
    : schedule = schedule ?? ReminderNotifications.schedule, cancel = cancel ?? ReminderNotifications.cancel;
  final Future<bool> Function(int,DateTime) schedule;
  final Future<void> Function(int) cancel;
  Future<List<Map<String, Object?>>> list({int? accountId}) async => (await DBHelper.database).rawQuery('''
    SELECT f.*,a.name AS account_name FROM follow_ups f LEFT JOIN accounts a ON a.id=f.account_id
    ${accountId == null ? '' : 'WHERE f.account_id=?'} ORDER BY f.status,f.due_at,f.id''', [if (accountId != null) accountId]);
  Future<int> create({int? accountId,int? obligationId,required String title,required DateTime dueAtUtc,
      String note = '',bool notify = false}) async {
    if (!dueAtUtc.isUtc || title.trim().isEmpty || title.length > 200 || note.length > 2000) throw ArgumentError('Invalid follow-up');
    final db = await DBHelper.database;
    final id = await db.transaction((txn) async {
      final id = await txn.insert('follow_ups', {'account_id': accountId,'obligation_id': obligationId,'title': title.trim(),
        'note': note,'due_at': dueAtUtc.toIso8601String(),'created_at': DateTime.now().toUtc().toIso8601String()});
      await txn.insert('app_audit', {'entity': 'follow_up','record_id': id,'operation': 'insert','new_label': title.trim(),'new_date': dueAtUtc.toIso8601String()});
      return id;
    });
    if (notify) {try {await enableReminder(id);} catch (_) { /* The saved follow-up is not a failed save. */ }}
    return id;
  }
  Future<bool> enableReminder(int id) async {
    final db = await DBHelper.database;
    final records = await db.query('follow_ups', where: 'id=? AND status=?', whereArgs: [id,'open']);
    if (records.length != 1) return false;
    bool scheduled;
    try {scheduled = await schedule(id, DateTime.parse(records.single['due_at'] as String));} catch (_) {scheduled = false;}
    final changed = await db.update('follow_ups', {'notification_scheduled': scheduled ? 1 : 0}, where: 'id=? AND status=?', whereArgs: [id,'open']);
    if (changed == 0) {if (scheduled) {try {await cancel(id);} catch (_) {}} return false;}
    return scheduled;
  }
  Future<void> setDone(int id, bool done) async {
    final db = await DBHelper.database;
    await db.transaction((txn) async {
      final changed = await txn.update('follow_ups', {'status': done ? 'done' : 'open','notification_scheduled': 0,
        'completed_at': done ? DateTime.now().toUtc().toIso8601String() : null}, where: 'id=?', whereArgs: [id]);
      if (changed != 1) throw StateError('Follow-up not found');
      await txn.insert('app_audit', {'entity': 'follow_up','record_id': id,'operation': done ? 'complete' : 'reopen'});
    });
    try {await cancel(id);} catch (_) { /* Completion has already committed. */ }
  }
}
