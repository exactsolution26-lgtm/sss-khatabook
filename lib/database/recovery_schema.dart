import 'package:sqflite/sqflite.dart';

/// Local device audit. Device time and imported records are not server verified.
class RecoverySchema {
  static Future<void> install(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS app_audit (
      id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
      entity TEXT NOT NULL, record_id INTEGER, operation TEXT NOT NULL,
      old_amount REAL, new_amount REAL, old_label TEXT, new_label TEXT,
      old_contact_name TEXT, new_contact_name TEXT,
      old_contact_phone TEXT, new_contact_phone TEXT,
      old_date TEXT, new_date TEXT, old_mode TEXT, new_mode TEXT,
      old_category TEXT, new_category TEXT,
      occurred_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    )''');
    for (final action in ['UPDATE', 'DELETE']) {
      await db.execute('''CREATE TRIGGER IF NOT EXISTS audit_no_${action.toLowerCase()}
        BEFORE $action ON app_audit BEGIN
        SELECT RAISE(ABORT,'Audit history is append only'); END''');
    }
    for (final table in ['accounts', 'income', 'expenses']) {
      for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
        String value(String alias, String column) => '$alias.$column';
        final account = table == 'accounts';
        final label = account ? 'name' : table == 'income' ? 'description' : 'note';
        String fields(String alias, bool exists) {
          if (!exists) return List.filled(8, 'NULL').join(',');
          return [account ? 'opening_balance' : 'amount', label,
            account ? null : 'contact_name', account ? null : 'contact_phone',
            account ? 'created_at' : 'date', account ? null : 'mode',
            account ? null : 'category', null]
            .take(7).map((c) => c == null ? 'NULL' : value(alias, c)).join(',');
        }
        // Seven typed before/after values; no JSON1 extension is required.
        final old = action == 'INSERT' ? List.filled(7, 'NULL').join(',') : fields('OLD', true);
        final next = action == 'DELETE' ? List.filled(7, 'NULL').join(',') : fields('NEW', true);
        await db.execute('''CREATE TRIGGER IF NOT EXISTS audit_${table}_${action.toLowerCase()}
          AFTER $action ON $table BEGIN INSERT INTO app_audit(
          entity,record_id,operation,
          old_amount,old_label,old_contact_name,old_contact_phone,old_date,old_mode,old_category,
          new_amount,new_label,new_contact_name,new_contact_phone,new_date,new_mode,new_category)
          VALUES('$table',${action == 'DELETE' ? 'OLD' : 'NEW'}.id,'${action.toLowerCase()}',$old,$next); END''');
      }
    }
  }
}
