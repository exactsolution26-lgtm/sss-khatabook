import '../db_helper.dart';

class AccountTable {
  static Future<void> saveOpeningBalance({
    required double cash,
    required double bank,
  }) async {
    if (!cash.isFinite || !bank.isFinite || cash < 0 || bank < 0) {
      throw ArgumentError('Opening balances must be finite and non-negative.');
    }

    final db = await DBHelper.database;
    await db.transaction((txn) async {
      // Preserve the existing single-account schema without deleting rows.
      final existing = await txn.query('accounts', columns: ['id'], limit: 1);
      if (existing.isEmpty) {
        await txn.insert('accounts', {
          'id': 1,
          'cash_balance': cash,
          'bank_balance': bank,
        });
      } else {
        await txn.update(
          'accounts',
          {'cash_balance': cash, 'bank_balance': bank},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    });
  }
}
