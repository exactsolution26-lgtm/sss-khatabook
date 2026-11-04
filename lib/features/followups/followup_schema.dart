import 'package:sqflite/sqflite.dart';

class FollowupSchema {
  static Future<void> install(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS follow_ups (
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER REFERENCES accounts(id),
      obligation_id INTEGER REFERENCES obligations(id), title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 200),
      note TEXT NOT NULL, due_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','done')),
      notification_scheduled INTEGER NOT NULL DEFAULT 0 CHECK(notification_scheduled IN (0,1)),
      created_at TEXT NOT NULL, completed_at TEXT
    )''');
    for (final operation in ['INSERT','UPDATE']) {
      await db.execute('''CREATE TRIGGER IF NOT EXISTS followup_owner_${operation.toLowerCase()} BEFORE $operation ON follow_ups
        WHEN NEW.obligation_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM obligations WHERE id=NEW.obligation_id AND account_id IS NEW.account_id)
        BEGIN SELECT RAISE(ABORT,'Follow-up belongs to another account'); END''');
    }
  }
}
