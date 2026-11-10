import '../../core/utils/money.dart';
import '../../database/db_helper.dart';
import '../entries/party_snapshot.dart';
import '../entries/attachments.dart';
import '../entries/record_recovery.dart';
import '../../database/tables/income_table.dart';
import '../../models/income_model.dart';

class IncomeController {
  final DbHelper _dbHelper = DbHelper.instance;

  void _validate(IncomeModel income) {
    if (income.accountId <= 0 ||
        !income.amount.isFinite ||
        income.amount <= 0) {
      throw ArgumentError(
        'Select an account and enter a positive finite amount',
      );
    }
  }

  Future<int> createIncome(IncomeModel income, {List<PendingAttachment> attachments = const []}) async {
    _validate(income);
    Money.parse(income.amount.toString());
    final db = await _dbHelper.database;
    final snapshot = PartySnapshot.optional(income.contactName, income.contactPhone);
    final values = income.toMap()
      ..remove('id')
      ..['created_at'] = DateTime.now().toUtc().toIso8601String()
      ..['updated_at'] = null;
    values.addAll(snapshot?.toMap() ?? {'contact_name': null, 'contact_phone': null});
    return db.transaction((txn) async {
      final id = await txn.insert(IncomeTable.tableName, values);
      await AttachmentStore.insertBatch(txn, attachments, incomeId: id);
      return id;
    });
  }

  Future<IncomeModel> getIncomeById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(IncomeTable.tableName, where: 'id = ?', whereArgs: [id]);
    if (rows.length != 1) throw StateError('Income entry not found');
    return IncomeModel.fromMap(rows.single);
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
    _validate(income);
    if (income.id == null) throw ArgumentError('Income ID required');
    final db = await _dbHelper.database;
    final snapshot = PartySnapshot.optional(income.contactName, income.contactPhone);
    return db.transaction((txn) async {
      final original = await txn.query(IncomeTable.tableName,
        where: 'id = ? AND account_id = ?', whereArgs: [income.id, income.accountId]);
      if (original.length != 1) throw StateError('Income entry not found for this account');
      final values = income.toMap()
        ..remove('id')
        ..['created_at'] = original.single['created_at']
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
      values.addAll(snapshot?.toMap() ?? {'contact_name': null, 'contact_phone': null});
      return txn.update(IncomeTable.tableName, values,
        where: 'id = ? AND account_id = ?', whereArgs: [income.id, income.accountId]);
    });
  }

  Future<int> deleteIncome(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(IncomeTable.tableName, where: 'id=?', whereArgs: [id]);
    if (rows.length != 1) throw StateError('Income entry not found');
    await RecordRecovery.remove(income: true,id: id,accountId: rows.single['account_id'] as int,reason: 'Deleted by local account owner');
    return 1;
  }
}
