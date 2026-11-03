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
}
