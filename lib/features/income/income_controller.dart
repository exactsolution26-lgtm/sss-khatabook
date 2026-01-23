import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../../database/tables/income_table.dart';
import '../../models/income_model.dart';

class IncomeController {
  final DbHelper _dbHelper = DbHelper.instance;

  Future<int> createIncome(IncomeModel income) async {
    final db = await _dbHelper.database;
    return await db.insert(
      IncomeTable.tableName,
      income.toMap(),
    );
  }

  Future<List<IncomeModel>> getAllIncome() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      IncomeTable.tableName,
      orderBy: '${IncomeTable.date} DESC',
    );
    return maps.map((map) => IncomeModel.fromMap(map)).toList();
  }

  Future<List<IncomeModel>> getIncomeByAccount(int accountId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      IncomeTable.tableName,
      where: '${IncomeTable.accountId} = ?',
      whereArgs: [accountId],
      orderBy: '${IncomeTable.date} DESC',
    );
    return maps.map((map) => IncomeModel.fromMap(map)).toList();
  }

  Future<double> getTotalIncomeByAccount(int accountId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(${IncomeTable.amount}) as total FROM ${IncomeTable.tableName} WHERE ${IncomeTable.accountId} = ?',
      [accountId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> updateIncome(IncomeModel income) async {
    final db = await _dbHelper.database;
    return await db.update(
      IncomeTable.tableName,
      income.toMap(),
      where: '${IncomeTable.id} = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> deleteIncome(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      IncomeTable.tableName,
      where: '${IncomeTable.id} = ?',
      whereArgs: [id],
    );
  }
}
