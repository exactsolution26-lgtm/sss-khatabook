import '../db_helper.dart';
import '../../models/account_model.dart';

class AccountTable {
  static Future<void> saveOpeningBalance({
    required double cash,
    required double bank,
  }) async {
    if (!cash.isFinite || !bank.isFinite || cash < 0 || bank < 0) {
      throw ArgumentError('Invalid opening balance');
    }
    final db = await DBHelper.database;
    await db.transaction((txn) async {
      final existing = await txn.query('accounts', orderBy: 'id ASC', limit: 1);
      if (existing.isEmpty) {
        await txn.insert('accounts', {
          'name': 'Main Account',
          'opening_balance': cash + bank,
          'cash_balance': cash,
          'bank_balance': bank,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await txn.update('accounts', {
          'opening_balance': cash + bank,
          'cash_balance': cash,
          'bank_balance': bank,
        }, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    });
  }

  static Future<List<AccountModel>> getAllAccounts() async {
    final db = await DBHelper.database;
    final rows = await db.query('accounts', orderBy: 'id ASC');
    return rows.map(AccountModel.fromMap).toList();
  }
}
