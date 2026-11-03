import '../db_helper.dart';
import '../../core/utils/money.dart';

class AccountTable {
  static Future<void> saveOpeningBalance({required double cash, required double bank}) async {
    if (!cash.isFinite || !bank.isFinite || cash < 0 || bank < 0) {
      throw ArgumentError('Invalid opening balance');
    }
    if ((cash * 100 - (cash * 100).roundToDouble()).abs() > 0.000001 ||
        (bank * 100 - (bank * 100).roundToDouble()).abs() > 0.000001) {
      throw ArgumentError('At most two decimal places allowed');
    }
    final cashPaise = Money.parseRupees(cash.toStringAsFixed(2)).paise;
    final bankPaise = Money.parseRupees(bank.toStringAsFixed(2)).paise;
    final db = await DBHelper.database;
    await db.transaction((txn) async {
      await txn.update('accounts', {'balance_paise': cashPaise},
          where: 'id = ?', whereArgs: ['local-cash']);
      await txn.update('accounts', {'balance_paise': bankPaise},
          where: 'id = ?', whereArgs: ['local-bank']);
    });
  }
}
