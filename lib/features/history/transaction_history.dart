import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;

/// Reads the current offline workspace. This is not a SaaS tenant boundary.
class HistoryEntry {
  HistoryEntry(this.row, {required this.income});
  final Map<String, Object?> row;
  final bool income;
  int get id => row['id'] as int;
  int? get accountId => row['account_id'] as int?;
  int get paise => ((row['amount'] as num) * 100).round();
  String get account => row['account_name'] as String;
  String get date => row['date'] as String;
  String get category => _text('category').isEmpty ? 'Other' : _text('category');
  String get mode => _text('mode').isEmpty ? 'Unknown' : _text('mode');
  String get name => _text('contact_name');
  String get phone => _text('contact_phone');
  String get note => _text('note');
  String get reference => '${income ? 'INC' : 'EXP'}-$id';
  int get attachmentCount => (row['attachment_count'] as num).toInt();
  String _text(String key) => row[key]?.toString() ?? '';

  static String accountingDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return dates.DateUtils.formatIstDateTime(DateTime.utc(date.year, date.month, date.day))
      .split(' · ').first;
  }

  static String timestamp(Object? value) {
    if (value == null || value.toString().isEmpty) return 'Unknown historic save time';
    final text = value.toString();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return 'Unknown historic save time';
    // A historic offset-free timestamp cannot establish an exact India time.
    if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(text)) {
      return '$text (historic timezone unknown)';
    }
    return dates.DateUtils.formatIstDateTime(parsed);
  }
}

class TransactionHistory {
  static Future<List<HistoryEntry>> load(bool income, {int? id, int? accountId}) async {
    final table = income ? 'income' : 'expenses';
    final note = income ? 'description' : 'note';
    final link = income ? 'income_id' : 'expense_id';
    final clauses = <String>[];
    final args = <Object?>[];
    if (id != null) { clauses.add('e.id = ?'); args.add(id); }
    if (accountId != null) { clauses.add('e.account_id = ?'); args.add(accountId); }
    final rows = await (await DBHelper.database).rawQuery('''
      SELECT e.id,e.account_id,e.amount,e.date,e.$note AS note,e.created_at,
        e.updated_at,e.contact_name,e.contact_phone,e.category,e.mode,
        COALESCE(a.name,'Unassigned legacy account') AS account_name,
        (SELECT COUNT(*) FROM attachments f WHERE f.$link=e.id) AS attachment_count
      FROM $table e LEFT JOIN accounts a ON a.id=e.account_id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY e.date DESC,e.created_at DESC,e.id DESC
    ''', args);
    return rows.map((r) => HistoryEntry(r, income: income)).toList();
  }

  static List<HistoryEntry> filter(List<HistoryEntry> entries, {
    String query = '', String? category, String? fromDate, String? toDate,
  }) {
    final text = query.trim().toLowerCase();
    return entries.where((e) =>
      (category == null || e.category == category) &&
      (fromDate == null || e.date.compareTo(fromDate) >= 0) &&
      (toDate == null || e.date.compareTo(toDate) <= 0) &&
      [e.name,e.phone,e.note,e.account,e.reference,e.category,e.mode]
        .join(' ').toLowerCase().contains(text)).toList();
  }

  static int totalPaise(Iterable<HistoryEntry> entries) =>
    entries.fold(0, (sum, entry) => sum + entry.paise);
}
