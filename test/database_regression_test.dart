import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/expenses/expense_controller.dart';
import 'package:offline_khata_app/features/income/income_controller.dart';
import 'package:offline_khata_app/models/expense_model.dart';
import 'package:offline_khata_app/models/income_model.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/features/entries/record_recovery.dart';
import 'package:offline_khata_app/features/whatsapp/whatsapp_share_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory temporary;

  setUp(() async {
    await DBHelper.close();
    temporary = await Directory.systemTemp.createTemp('sss-db-test-');
    await databaseFactory.setDatabasesPath(temporary.path);
  });
  tearDown(() async {
    await DBHelper.close();
    await temporary.delete(recursive: true);
  });

  test(
    'actual Dart migration preserves v1 data and legacy ownership',
    () async {
      final path = '${temporary.path}/offline_khata.db';
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE accounts(id INTEGER PRIMARY KEY, cash_balance REAL, bank_balance REAL)',
            );
            await db.execute(
              'CREATE TABLE expenses(id INTEGER PRIMARY KEY, amount REAL, mode TEXT, category TEXT, note TEXT, date TEXT)',
            );
            await db.execute('INSERT INTO accounts VALUES (7,125.25,300.75)');
            await db.execute(
              "INSERT INTO expenses VALUES (11,20.5,'cash','food','legacy','2026-10-01')",
            );
          },
        ),
      );
      await legacy.close();
      final db = await DBHelper.database;
      final rows = await db.query('accounts');
      expect(rows.single['id'], 7);
      expect(rows.single['opening_balance'], 426);
      expect((await db.query('expenses')).single['account_id'], isNull);
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('archived accounts reject edits and cannot be erased with pending dues', () async {
    await AccountTable.saveAccount(name: 'Customer', openingBalance: 0);
    final account = (await AccountTable.getAllAccounts()).single;
    final db = await DBHelper.database;
    await db.insert('obligations', {
      'account_id': account.id!, 'kind': 'receivable', 'total_paise': 100,
      'description': 'Outstanding', 'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await expectLater(AccountTable.deleteEmptyAccount(account.id!), throwsStateError);
    await AccountTable.archive(account.id!, archived: true);
    expect(await AccountTable.getAllAccounts(), isEmpty);
    await expectLater(AccountTable.saveAccount(
      id: account.id, name: 'Unauthorized edit', openingBalance: 0,
    ), throwsStateError);
    expect((await AccountTable.getAllAccounts(includeArchived: true)).single.name, 'Customer');
    await AccountTable.archive(account.id!, archived: false);
    expect((await AccountTable.getAllAccounts()).single.name, 'Customer');
  });

  test('archived account rejects financial inserts until restored', () async {
    await AccountTable.saveAccount(name: 'Archived customer', openingBalance: 0);
    final account = (await AccountTable.getAllAccounts()).single;
    await AccountTable.archive(account.id!, archived: true);
    final db = await DBHelper.database;
    await expectLater(db.insert('income', {
      'account_id': account.id, 'amount': 10,
      'date': '2026-11-04', 'created_at': DateTime.now().toUtc().toIso8601String(),
    }), throwsA(isA<DatabaseException>()));
    await expectLater(db.insert('expenses', {
      'account_id': account.id, 'amount': 10,
      'date': '2026-11-04', 'created_at': DateTime.now().toUtc().toIso8601String(),
    }), throwsA(isA<DatabaseException>()));
    await AccountTable.archive(account.id!, archived: false);
    final saved = await IncomeController().createIncome(IncomeModel(
      accountId: account.id, amount: 10,
      date: DateTime(2026, 11, 4), createdAt: DateTime.now(),
    ));
    expect(saved, greaterThan(0));
  });

  test('archived account prevents edit, removal and recycle restore', () async {
    await AccountTable.saveAccount(name: 'Locked', openingBalance: 0);
    final id = (await AccountTable.getAllAccounts()).single.id!;
    final incomeId = await IncomeController().createIncome(IncomeModel(
      accountId: id, amount: 25, date: DateTime(2026, 11, 4),
      createdAt: DateTime.now(),
    ));
    final archiveId = await RecordRecovery.remove(
      income: true, id: incomeId, accountId: id, reason: 'Correction');
    await AccountTable.archive(id, archived: true);
    await expectLater(RecordRecovery.restore(archiveId, id), throwsStateError);
    await AccountTable.archive(id, archived: false);
    await RecordRecovery.restore(archiveId, id);
    await AccountTable.archive(id, archived: true);
    await expectLater(RecordRecovery.remove(
      income: true, id: incomeId, accountId: id, reason: 'Correction'),
      throwsStateError);
    await expectLater(RecordRecovery.edit(
      income: true, id: incomeId, accountId: id, amount: '30',
      date: '2026-11-04', note: 'Blocked', category: 'Other',
      mode: 'cash', name: '', phone: ''),
      throwsStateError);
    expect((await (await DBHelper.database).query('income',
      where: 'id=?', whereArgs: [incomeId])).single['amount'], 25);
  });

  test('history keyset pages preserve ties, account and type filters', () async {
    await AccountTable.saveAccount(name: 'A', openingBalance: 0);
    await AccountTable.saveAccount(name: 'B', openingBalance: 0);
    final accounts = await AccountTable.getAllAccounts();
    final a = accounts.first.id!;
    final b = accounts.last.id!;
    for (var i = 0; i < 5; i++) {
      await IncomeController().createIncome(IncomeModel(
        accountId: a, amount: i + 1.0, date: DateTime(2026, 11, 4),
        createdAt: DateTime.now(),
      ));
    }
    await IncomeController().createIncome(IncomeModel(
      accountId: b, amount: 99, date: DateTime(2026, 11, 4),
      createdAt: DateTime.now(),
    ));
    final logic = AnalysisLogic();
    final all = <Map<String, Object?>>[];
    String? date;
    String? kind;
    int? id;
    while (true) {
      final page = await logic.getHistoryPage(
        accountId: a, beforeDate: date, beforeKind: kind, beforeId: id, limit: 2);
      if (page.isEmpty) break;
      all.addAll(page);
      date = page.last['date'] as String;
      kind = page.last['kind'] as String;
      id = page.last['id'] as int;
    }
    expect(all.length, 5);
    expect(all.map((e) => e['id']).toSet().length, 5);
    expect(all.every((e) => e['account_id'] == a), isTrue);
    expect(all.map((e) => e['id']).toList(),
      orderedEquals([...all.map((e) => e['id'] as int)]..sort((x,y)=>y.compareTo(x))));
    expect((await logic.getHistoryPage(accountId: a, kind: 'expense')), isEmpty);
    expect((await logic.getHistoryPage(accountId: a, fromDate: '2026-11-05')), isEmpty);
    await expectLater(logic.getHistoryPage(limit: 101), throwsArgumentError);
    await expectLater(logic.getHistoryPage(beforeDate: '2026-11-04'), throwsArgumentError);
  });

  test('new expenses are included in the selected account only', () async {
    await AccountTable.saveAccount(name: 'A', openingBalance: 100);
    await AccountTable.saveAccount(name: 'B', openingBalance: 200);
    final accounts = await AccountTable.getAllAccounts();
    await ExpenseController().saveExpense(
      ExpenseModel(
        accountId: accounts.first.id,
        amount: 12.5,
        mode: 'cash',
        category: 'test',
        note: '',
        date: '2026-11-04',
      ),
    );
    expect(
      await ExpenseController().getTotalExpensesByAccount(accounts.first.id!),
      12.5,
    );
    expect(
      await ExpenseController().getTotalExpensesByAccount(accounts.last.id!),
      0,
    );
    await expectLater(
      AccountTable.deleteEmptyAccount(accounts.first.id!),
      throwsStateError,
    );
  });

  test(
    'foreign keys and controller validation reject invalid finance',
    () async {
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          IncomeController().createIncome(
            IncomeModel(
              accountId: 1,
              amount: amount,
              date: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        ExpenseController().saveExpense(
          ExpenseModel(
            amount: 10,
            mode: 'cash',
            category: '',
            note: '',
            date: '2026-11-04',
          ),
        ),
        throwsArgumentError,
      );
      final db = await DBHelper.database;
      await expectLater(
        db.insert('income', {
          'account_id': 99,
          'amount': 10,
          'date': '2026-11-04',
          'created_at': '2026-11-04',
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('concurrent open requests share one database and opening edit preserves records', () async {
    final databases = await Future.wait(
      List.generate(20, (_) => DBHelper.database),
    );
    expect(databases.every((db) => identical(db, databases.first)), isTrue);
    await AccountTable.saveOpeningBalance(cash: 50, bank: 25);
    final id = (await AccountTable.getAllAccounts()).single.id!;
    await IncomeController().createIncome(
      IncomeModel(
        accountId: id,
        amount: 10,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    await expectLater(
      AccountTable.saveOpeningBalance(cash: 60, bank: 30),
      throwsA(isA<DatabaseException>()),
    );
    expect((await AccountTable.getAllAccounts()).single.id, id);
    expect(await IncomeController().getTotalIncomeByAccount(id), 10);
    expect((await AccountTable.getAllAccounts()).single.openingBalance, 75);
  });
  test('financial sharing ignores forged manual amounts and requires saved records', () async {
    await AccountTable.saveAccount(
      name: 'Recorded customer',
      openingBalance: 100,
    );
    final account = (await AccountTable.getAllAccounts()).single;
    final incomeId = await IncomeController().createIncome(
      IncomeModel(
        accountId: account.id!,
        amount: 12.5,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    final verified = await const WhatsAppShareService().resolveDraft(
      WhatsAppDraft(
        type: WhatsAppMessageType.receipt,
        customer: 'Forged name',
        amount: 999999,
        timestampUtc: DateTime.now().toUtc(),
        sourceIncomeId: incomeId,
      ),
    );
    expect(verified.customer, 'Recorded customer');
    expect(verified.amount, 12.5);
    expect(verified.message, isNot(contains('999999')));
    await expectLater(
      const WhatsAppShareService().resolveDraft(
        WhatsAppDraft(
          type: WhatsAppMessageType.receipt,
          customer: 'Fake',
          amount: 100,
          timestampUtc: DateTime.now().toUtc(),
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      const WhatsAppShareService().resolveDraft(
        WhatsAppDraft(
          type: WhatsAppMessageType.receipt,
          customer: 'Missing',
          amount: 100,
          timestampUtc: DateTime.now().toUtc(),
          sourceIncomeId: incomeId + 99,
        ),
      ),
      throwsStateError,
    );
  });

  test('unassigned legacy expenses appear in global reports without guessed ownership', () async {
    final path = '${temporary.path}/offline_khata.db';
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE accounts(id INTEGER PRIMARY KEY, cash_balance REAL, bank_balance REAL)',
          );
          await db.execute(
            'CREATE TABLE expenses(id INTEGER PRIMARY KEY, amount REAL, mode TEXT, category TEXT, note TEXT, date TEXT)',
          );
          await db.execute('INSERT INTO accounts VALUES (7,100,0)');
          await db.execute(
            "INSERT INTO expenses VALUES (11,20,'cash','','legacy','2026-10-01')",
          );
        },
      ),
    );
    await legacy.close();
    final report = await AnalysisLogic().getAnalysisData();
    expect(report['totalExpense'], 20);
    expect(report['totalBalance'], 80);
    expect(report['unassignedExpenseCount'], 1);
    expect((report['accountDetails'] as List).single['expense'], 0);
  });

  test('saved income contact snapshot and original save time survive edits', () async {
    await AccountTable.saveAccount(name: 'Account', openingBalance: 1000);
    final account = (await AccountTable.getAllAccounts()).single;
    final id = await IncomeController().createIncome(IncomeModel(
      accountId: account.id!, amount: 50, date: DateTime(2026, 10, 1),
      createdAt: DateTime.utc(2000), contactName: ' Ravi Verma ',
      contactPhone: '98765 43210', category: 'Commission / Brokerage', mode: 'cash'));
    final original = await IncomeController().getIncomeById(id);
    expect(original.contactName, 'Ravi Verma');
    expect(original.contactPhone, '+919876543210');
    expect(original.createdAt.year, greaterThan(2000));
    expect(original.date, DateTime(2026, 10, 1));
    await IncomeController().updateIncome(original.copyWith(
      amount: 75, createdAt: DateTime.utc(1990)));
    final updated = await IncomeController().getIncomeById(id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt, isNotNull);
    expect(updated.contactName, 'Ravi Verma');
    await (await DBHelper.database).update('accounts', {'name': 'Renamed account'});
    final draft = await const WhatsAppShareService().resolveDraft(WhatsAppDraft(
      type: WhatsAppMessageType.receipt, customer: 'Forged', amount: 999,
      timestampUtc: DateTime.utc(1990), sourceIncomeId: id));
    expect(draft.customer, 'Ravi Verma');
    expect(draft.amount, 75);
    expect(draft.timestampUtc, original.createdAt.toUtc());
    expect(draft.recipientPhone, '+919876543210');
    await expectLater(const WhatsAppShareService().openDraft('9876543210', WhatsAppDraft(
      type: WhatsAppMessageType.receipt, customer: '', amount: 0, timestampUtc: DateTime.utc(2000), sourceIncomeId: id),
      expectedMessage: 'An outdated or forged preview'), throwsStateError);
  });

  test('expense receipt uses normalized saved contact and a genuine save timestamp', () async {
    await AccountTable.saveAccount(name: 'Account', openingBalance: 1000);
    final account = (await AccountTable.getAllAccounts()).single;
    final saved = await ExpenseController().saveExpense(ExpenseModel(
      accountId: account.id, amount: 200, mode: 'cash', category: 'Travel',
      note: 'Site visit', date: '2026-10-01', contactName: 'Office Vendor',
      contactPhone: '+44 20 7946 0000', createdAt: DateTime.utc(2000)));
    expect(saved.id, isNotNull);
    expect(saved.contactName, 'Office Vendor');
    expect(saved.contactPhone, '+442079460000');
    expect(saved.createdAt!.year, greaterThan(2000));
    expect(saved.createdAt!.isUtc, isTrue);
    expect(saved.date, '2026-10-01');
    expect(saved.updatedAt, isNull);
    await DBHelper.close();
    final row = (await (await DBHelper.database).query('expenses')).single;
    expect(row['contact_name'], 'Office Vendor');
    expect(row['contact_phone'], '+442079460000');
    expect(row['created_at'], saved.createdAt!.toIso8601String());
  });

  test('incomplete or invalid contact snapshots cannot create financial rows', () async {
    await AccountTable.saveAccount(name: 'Account', openingBalance: 1000);
    final account = (await AccountTable.getAllAccounts()).single;
    for (final contact in [('', '9876543210'), ('Name', ''), ('Name', 'abc'), ('Name', '+0000000')]) {
      await expectLater(ExpenseController().saveExpense(ExpenseModel(
        accountId: account.id, amount: 1, mode: 'cash', category: 'Other',
        note: '', date: '2026-11-04', contactName: contact.$1, contactPhone: contact.$2)),
        throwsArgumentError);
    }
    expect(await (await DBHelper.database).query('expenses'), isEmpty);
  });

  test('custom categories are durable, case-insensitive and separated by entry kind', () async {
    final db = await DBHelper.database;
    await db.insert('entry_categories', {'kind': 'expense', 'name': 'Site Visit', 'created_at': '2026-11-04T00:00:00Z'});
    await expectLater(db.insert('entry_categories', {'kind': 'expense', 'name': 'site visit', 'created_at': '2026-11-04T00:00:00Z'}), throwsA(isA<DatabaseException>()));
    await db.insert('entry_categories', {'kind': 'income', 'name': 'Site Visit', 'created_at': '2026-11-04T00:00:00Z'});
    await DBHelper.close();
    expect(await (await DBHelper.database).query('entry_categories'), hasLength(2));
  });
}
