import 'package:sqflite/sqflite.dart';
import '../db_helper.dart';
import '../../models/account_model.dart';

class AccountTable {
  static const String tableName = 'accounts';
  static const String id = 'id';
  static const String name = 'name';
  static const String openingBalance = 'opening_balance';
  static const String createdAt = 'created_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $id INTEGER PRIMARY KEY AUTOINCREMENT,
      $name TEXT NOT NULL,
      $openingBalance REAL NOT NULL,
      $createdAt TEXT NOT NULL
    )
  ''';

  static Future<int> insert(AccountModel account) async {
    final db = await DBHelper.instance.database;
    return await db.insert(tableName, account.toMap());
  }

  static Future<AccountModel?> getById(int id) async {
    final db = await DBHelper.instance.database;
    final maps = await db.query(
      tableName,
      where: '$id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return AccountModel.fromMap(maps.first);
    }
    return null;
  }

  static Future<List<AccountModel>> getAll() async {
    final db = await DBHelper.instance.database;
    final maps = await db.query(tableName);
    return maps.map((map) => AccountModel.fromMap(map)).toList();
  }

  static Future<int> update(AccountModel account) async {
    final db = await DBHelper.instance.database;
    return await db.update(
      tableName,
      account.toMap(),
      where: '$id = ?',
      whereArgs: [account.id],
    );
  }

  static Future<int> delete(int id) async {
    final db = await DBHelper.instance.database;
    return await db.delete(
      tableName,
      where: '$id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> saveOpeningBalance({
    required double cash,
    required double bank,
  }) async {
    final db = await DBHelper.instance.database;
    await db.delete(tableName);
    await db.insert(
      tableName,
      {
        'name': 'Opening Balance',
        'opening_balance': cash + bank,
        'created_at': DateTime.now().toString(),
      },
    );
  }
}
