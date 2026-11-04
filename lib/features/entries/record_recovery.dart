import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../database/db_helper.dart';
import '../../core/utils/money.dart';
import '../../core/utils/date_utils.dart' as dates;
import 'party_snapshot.dart';
import 'attachments.dart';

/// Recycle records stay in the same local workspace and encrypted backups.
/// Payment allocations must be reversed through Dues, never edited/deleted here.
class RecordRecovery {
  static Future<void> install(DatabaseExecutor db) => db.execute('''CREATE TABLE IF NOT EXISTS recycled_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL CHECK(kind IN ('income','expenses')),
    record_id INTEGER NOT NULL, account_id INTEGER NOT NULL REFERENCES accounts(id),
    payload TEXT NOT NULL, reason TEXT NOT NULL, deleted_at TEXT NOT NULL,
    restored_at TEXT, UNIQUE(kind,record_id,deleted_at))''');
  static String table(bool income) => income ? 'income' : 'expenses';
  static Future<void> _unallocated(DatabaseExecutor db, bool income, int id) async {
    final column = income ? 'income_id' : 'expense_id';
    if ((await db.rawQuery('SELECT id FROM payment_allocations WHERE $column=? OR reversal_$column=? LIMIT 1',[id,id])).isNotEmpty) {
      throw StateError('Use payment history to reverse allocated payments');
    }
  }
  static Future<void> edit({required bool income, required int id, required int accountId,
      required String amount, required String date, required String note, required String category,
      required String mode, required String name, required String phone}) async {
    final paise = Money.parse(amount);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) || DateTime.tryParse(date) == null ||
        dates.DateUtils.formatDate(DateTime.parse(date)) != date ||
        DateTime.parse(date).isAfter(dates.DateUtils.indiaToday()) || note.length > 2000 ||
        category.trim().isEmpty || category.length > 60 || !['cash','online','bank','upi','card'].contains(mode)) {
      throw ArgumentError('Check date, category, note and payment mode');
    }
    final contact = PartySnapshot.optional(name,phone);
    await (await DBHelper.database).transaction((txn) async {
      await _unallocated(txn,income,id);
      final count = await txn.update(table(income), {'amount': paise / 100,'date': date,
        income ? 'description' : 'note': note,'category': category.trim(),'mode': mode,
        ...?contact?.toMap(), if(contact == null) ...{'contact_name': null,'contact_phone': null},
        'updated_at': DateTime.now().toUtc().toIso8601String()},where: 'id=? AND account_id=?',whereArgs: [id,accountId]);
      if (count != 1) throw StateError('Entry not found in this account');
    });
  }
  static Future<int> remove({required bool income, required int id, required int accountId, required String reason}) async {
    if (reason.trim().isEmpty || reason.length > 500) throw ArgumentError('Deletion reason required');
    return (await DBHelper.database).transaction((txn) async {
      final rows = await txn.query(table(income),where: 'id=? AND account_id=?',whereArgs: [id,accountId]);
      if (rows.length != 1) throw StateError('Entry not found in this account');
      final attachments = await txn.query('attachments',where: '${income ? 'income_id' : 'expense_id'}=?',whereArgs: [id]);
      final archiveId = await txn.insert('recycled_entries',{'kind': table(income),'record_id': id,'account_id': accountId,
        'payload': jsonEncode({'entry': rows.single,'attachments': attachments}),
        'reason': reason.trim(),'deleted_at': DateTime.now().toUtc().toIso8601String()});
      // Foreign keys reject allocated/reversal records; the archive is rolled back too.
      await txn.delete(table(income),where: 'id=? AND account_id=?',whereArgs: [id,accountId]);
      return archiveId;
    });
  }
  static Future<List<Map<String,Object?>>> list({int? accountId}) async => (await DBHelper.database).query(
    'recycled_entries',columns: ['id','kind','record_id','account_id','reason','deleted_at','restored_at'],
    where: accountId == null ? 'restored_at IS NULL' : 'restored_at IS NULL AND account_id=?',
    whereArgs: accountId == null ? null : [accountId],orderBy: 'id DESC');
  static Future<Map<String,dynamic>> validatePayload(DatabaseExecutor db,Map<String,Object?> archive) async {
    final kind=archive['kind'];
    if(!['income','expenses'].contains(kind)) throw const FormatException('Invalid archived entry type');
    final payload=jsonDecode(archive['payload'] as String) as Map<String,dynamic>;
    final entry=Map<String,Object?>.from(payload['entry'] as Map);
    if(entry['id']!=archive['record_id'] || entry['account_id']!=archive['account_id'] ||
        entry['amount'] is! num || !(entry['amount'] as num).isFinite || (entry['amount'] as num)<=0 ||
        entry['date'] is! String || DateTime.tryParse(entry['date'] as String)==null) throw const FormatException('Invalid archived financial entry');
    final columns=(await db.rawQuery('PRAGMA table_info($kind)')).map((r)=>r['name']).toSet();
    if(!entry.keys.every(columns.contains)) throw const FormatException('Unknown archived financial fields');
    final files=payload['attachments'] as List;
    if(files.length>5) throw const FormatException('Too many archived attachments');
    var total=0;
    final fileColumns=(await db.rawQuery('PRAGMA table_info(attachments)')).map((r)=>r['name']).toSet();
    for(final value in files) {
      final file=Map<String,Object?>.from(value as Map);
      if(!file.keys.every(fileColumns.contains) || file[kind=='income' ? 'income_id' : 'expense_id']!=entry['id'] ||
          file[kind=='income' ? 'expense_id' : 'income_id']!=null) throw const FormatException('Invalid archived attachment link');
      final bytes=base64Decode(file['content_base64'] as String);
      final inspected=await PendingAttachment.inspect(file['name'] as String,bytes);
      total+=bytes.length;
      if(inspected.name!=file['name'] || inspected.mime!=file['mime_type'] || bytes.length!=file['size_bytes'] || total>10*1024*1024) throw const FormatException('Invalid archived attachment');
    }
    return payload;
  }
  static Future<void> restore(int archiveId, int accountId) async {
    await (await DBHelper.database).transaction((txn) async {
      final rows = await txn.query('recycled_entries',where: 'id=? AND account_id=? AND restored_at IS NULL',whereArgs: [archiveId,accountId]);
      if (rows.length != 1) throw StateError('Deleted entry not found');
      final row = rows.single;
      final payload = await validatePayload(txn,row);
      final entry = Map<String,Object?>.from(payload['entry'] as Map);
      if (entry['id'] != row['record_id'] || entry['account_id'] != accountId) throw StateError('Recovery identity mismatch');
      await txn.insert(row['kind'] as String,entry);
      for (final attachment in payload['attachments'] as List) {
        await txn.insert('attachments',Map<String,Object?>.from(attachment as Map));
      }
      await txn.update('recycled_entries',{'restored_at': DateTime.now().toUtc().toIso8601String()},where: 'id=?',whereArgs: [archiveId]);
      await txn.insert('app_audit',{'entity': row['kind'],'record_id': row['record_id'],'operation': 'recover','new_label': 'Restored deleted entry'});
    });
  }
}
