import '../db_helper.dart';
import '../../models/account_model.dart';

class AccountTable {
  static Future<void> saveAccount({
    required String name,
    required double openingBalance,
    int? id,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        !openingBalance.isFinite ||
        openingBalance < 0) {
      throw ArgumentError('Invalid account');
    }
    final db = await DBHelper.database;
    final values = <String, Object?>{
      'name': name.trim(),
      'opening_balance': openingBalance,
    };
    if (id == null) {
      values['created_at'] = DateTime.now().toUtc().toIso8601String();
      await db.insert('accounts', values);
    } else {
      final count = await db.update(
        'accounts',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count != 1) throw StateError('Account not found');
    }
  }

  static Future<void> deleteEmptyAccount(int id) async {
    final db = await DBHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT (SELECT COUNT(*) FROM income WHERE account_id = ?) + (SELECT COUNT(*) FROM expenses WHERE account_id = ?) AS count',
        [id, id],
      );
      if ((rows.first['count'] as num) != 0)
        throw StateError('Account has transactions');
      final account = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (account.isEmpty || (account.first['opening_balance'] as num) != 0)
        throw StateError('Only zero-balance empty accounts can be deleted');
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> archive(int id,{required bool archived}) async {
    await (await DBHelper.database).transaction((txn) async {
      final rows=await txn.query('accounts',where:'id=?',whereArgs:[id]);
      if(rows.length!=1)throw StateError('Account not found');
      if((rows.single['archived_at']!=null)==archived)return;
      await txn.update('accounts',{'archived_at':archived?DateTime.now().toUtc().toIso8601String():null},where:'id=?',whereArgs:[id]);
      await txn.insert('app_audit',{'entity':'accounts','record_id':id,'operation':archived?'archive':'unarchive','new_label':rows.single['name']});
    });
  }

  static Future<DateTime> saveOpeningBalance({
    required double cash,
    required double bank,
  }) async {
    if (!cash.isFinite || !bank.isFinite || !(cash + bank).isFinite || cash < 0 || bank < 0) {
      throw ArgumentError('Invalid opening balance');
    }
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final savedAt = DateTime.now().toUtc();
      final existing = await txn.query('accounts',where:'archived_at IS NULL',orderBy:'id ASC',limit:1);
      if (existing.isEmpty) {
        await txn.insert('accounts', {
          'name': 'Main Account',
          'opening_balance': cash + bank,
          'cash_balance': cash,
          'bank_balance': bank,
          'created_at': savedAt.toIso8601String(),
          'opening_balance_saved_at': savedAt.toIso8601String(),
        });
      } else {
        await txn.update(
          'accounts',
          {
            'opening_balance': cash + bank,
            'cash_balance': cash,
            'bank_balance': bank,
            'opening_balance_saved_at': savedAt.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
      return savedAt;
    });
  }

  static Future<List<AccountModel>> getAllAccounts({bool includeArchived=false}) async {
    final db = await DBHelper.database;
    final rows = await db.query('accounts', where:includeArchived?null:'archived_at IS NULL',orderBy: 'id ASC');
    return rows.map(AccountModel.fromMap).toList();
  }
}
