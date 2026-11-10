import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/recovery_schema.dart';
import 'package:offline_khata_app/database/tables/work_table.dart';
import 'package:offline_khata_app/features/dues/dues_schema.dart';
import 'package:offline_khata_app/features/entries/attachments.dart';
import 'package:offline_khata_app/features/entries/record_recovery.dart';
import 'package:offline_khata_app/features/followups/followup_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> createLegacySchema(Database db, int version) async {
  // Base columns are from the original schema 2–4 creation callbacks.
  await db.execute('''CREATE TABLE accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
    opening_balance REAL NOT NULL DEFAULT 0, cash_balance REAL NOT NULL DEFAULT 0,
    bank_balance REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL
    ${version >= 4 ? ', opening_balance_saved_at TEXT' : ''})''');
  await db.execute('''CREATE TABLE income (
    id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL,
    amount REAL NOT NULL, description TEXT, date TEXT NOT NULL, created_at TEXT NOT NULL,
    ${version >= 5 ? 'updated_at TEXT, contact_name TEXT, contact_phone TEXT, category TEXT, mode TEXT,' : ''}
    FOREIGN KEY (account_id) REFERENCES accounts(id))''');
  await db.execute('''CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER,
    amount REAL NOT NULL CHECK(amount > 0), mode TEXT, category TEXT, note TEXT, date TEXT NOT NULL,
    ${version >= 5 ? 'created_at TEXT, updated_at TEXT, contact_name TEXT, contact_phone TEXT,' : ''}
    FOREIGN KEY(account_id) REFERENCES accounts(id))''');
  await db.execute(WorkTable.createTable);
  if (version >= 3) {
    await db.execute('''CREATE TRIGGER account_opening_lock BEFORE UPDATE ON accounts
      WHEN (NEW.opening_balance IS NOT OLD.opening_balance
        OR NEW.cash_balance IS NOT OLD.cash_balance OR NEW.bank_balance IS NOT OLD.bank_balance)
        AND (EXISTS(SELECT 1 FROM income WHERE account_id = OLD.id)
          OR EXISTS(SELECT 1 FROM expenses WHERE account_id = OLD.id))
      BEGIN SELECT RAISE(ABORT, 'Opening balance locked after first transaction'); END''');
    for (final table in ['income', 'expenses']) {
      for (final action in ['INSERT', 'UPDATE']) {
        await db.execute('''CREATE TRIGGER ${table}_${action.toLowerCase()}_guard
          BEFORE $action ON $table
          WHEN NEW.account_id IS NULL OR NEW.amount IS NULL OR NEW.amount <= 0
            OR NEW.amount > 90000000000000
          BEGIN SELECT RAISE(ABORT, 'Invalid financial record'); END''');
      }
    }
  }
  if (version >= 5) {
    await db.execute('''CREATE TABLE entry_categories (
      kind TEXT NOT NULL CHECK(kind IN ('income','expense')), name TEXT NOT NULL
      CHECK(length(trim(name)) BETWEEN 1 AND 60), created_at TEXT NOT NULL,
      UNIQUE(kind,name COLLATE NOCASE))''');
  }
  if (version >= 6) await RecoverySchema.install(db);
  if (version >= 7) await AttachmentStore.install(db);
  if (version >= 8) {
    await DuesSchema.install(db);
    await FollowupSchema.install(db);
  }
  if (version >= 9) await RecordRecovery.install(db);
}

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  for (var version = 2; version <= 9; version++) {
    test('schema $version migrates existing financial records to schema 12', () async {
      final temp = await Directory.systemTemp.createTemp('sss-schema-$version-');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}/ledger.db';
      final legacy = await factory.openDatabase(path, options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: createLegacySchema,
      ));
      const savedAt = '2026-10-01T00:00:00Z';
      try {
        await legacy.insert('accounts', {'id': 7, 'name': 'Sample customer', 'opening_balance': 100.50, 'created_at': savedAt});
        await legacy.insert('income', {
          'id': 13, 'account_id': 7, 'amount': 12.34, 'date': '2026-10-01', 'created_at': savedAt,
          if (version >= 5) 'category': 'Sample category',
        });
        await legacy.insert('expenses', {'id': 11, 'account_id': 7, 'amount': 5.67, 'date': '2026-10-01'});
      } finally {
        await legacy.close();
      }

      final migrated = await DBHelper.openAt(path, factory: factory);
      try {
        expect((await migrated.rawQuery('PRAGMA user_version')).single.values.single, 12);
        final account = (await migrated.query('accounts')).single;
        expect(account['opening_balance'], 100.50);
        expect(account['archived_at'], isNull);
        final income = (await migrated.query('income')).single;
        expect(income['id'], 13);
        expect(income['amount'], 12.34);
        expect(income['created_at'], savedAt);
        expect(income['category'], version >= 5 ? 'Sample category' : null);
        final expense = (await migrated.query('expenses')).single;
        expect(expense['id'], 11);
        expect(expense['amount'], 5.67);
        expect(expense['account_id'], 7);
        if (version >= 6) expect(await migrated.query('app_audit'), hasLength(3));
        expect(await migrated.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect((await migrated.rawQuery('PRAGMA integrity_check')).single.values.single, 'ok');
      } finally {
        await migrated.close();
      }
    });
  }
}
