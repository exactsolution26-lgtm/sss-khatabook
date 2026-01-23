import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';

class AccountTable {
  static Future<void> saveOpeningBalance({
    required double cash,
    required double bank,
  }) async {
    final db = await DBHelper.database;

    await db.delete('accounts'); // only one record allowed

    await db.insert(
      'accounts',
      {
        'cash_balance': cash,
        'bank_balance': bank,
      },
    );
  }
}
