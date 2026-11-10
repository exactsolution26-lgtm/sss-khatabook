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

class HistoryPage {
  const HistoryPage(this.entries, this.hasNext, this.count, this.totalPaise, this.categories, this.accounts);
  final List<HistoryEntry> entries;
  final bool hasNext;
  final int count, totalPaise;
  final List<String> categories;
  final Map<int, String> accounts;
}

class TransactionHistory {
  // SQLite LOWER folds ASCII only. Build a literal GLOB with case alternatives
  // for letters so pagination preserves search on accented names as well.
  static String _searchPattern(String query) {
    final pattern = StringBuffer('*');
    for (final rune in query.trim().toLowerCase().runes) {
      final letter = String.fromCharCode(rune);
      final upper = letter.toUpperCase();
      if (letter == '[' || letter == '*' || letter == '?') {
        pattern.write('[$letter]');
      } else if (upper != letter && upper.runes.length == 1 && upper.toLowerCase() == letter) {
        pattern.write('[$letter$upper]');
      } else {
        pattern.write(letter);
      }
    }
    return '${pattern.toString()}*';
  }

  static String _entriesSql(bool income) {
    final note = income ? 'description' : 'note';
    final link = income ? 'income_id' : 'expense_id';
    return '''SELECT e.id,e.account_id,e.amount,e.date,e.$note AS note,e.created_at,
      e.updated_at,e.contact_name,e.contact_phone,e.category,e.mode,
      COALESCE(a.name,'Unassigned legacy account') AS account_name,
      (SELECT COUNT(*) FROM attachments f WHERE f.$link=e.id) AS attachment_count''';
  }

  static Future<List<HistoryEntry>> load(bool income, {int? id, int? accountId}) async {
    final table = income ? 'income' : 'expenses';
    final clauses = <String>[];
    final args = <Object?>[];
    if (id != null) { clauses.add('e.id = ?'); args.add(id); }
    if (accountId != null) { clauses.add('e.account_id = ?'); args.add(accountId); }
    final rows = await (await DBHelper.database).rawQuery('''
      ${_entriesSql(income)}
      FROM $table e LEFT JOIN accounts a ON a.id=e.account_id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY e.date DESC,e.created_at DESC,e.id DESC
    ''', args);
    return rows.map((r) => HistoryEntry(r, income: income)).toList();
  }

  static Future<HistoryPage> page(bool income, {
    int? accountId, String query = '', String? category, String? fromDate,
    String? toDate, HistoryEntry? after, int size = 50,
  }) async {
    if (size < 1 || size > 100) throw ArgumentError.value(size, 'size');
    if (after != null && after.income != income) throw ArgumentError('Mismatched transaction type');
    final table = income ? 'income' : 'expenses';
    final note = income ? 'description' : 'note';
    final prefix = income ? 'INC-' : 'EXP-';
    const accountName = "COALESCE(a.name,'Unassigned legacy account')";
    const categoryName = "COALESCE(NULLIF(e.category,''),'Other')";
    const mode = "COALESCE(NULLIF(e.mode,''),'Unknown')";
    const created = "COALESCE(e.created_at,'')";
    final clauses = <String>[];
    final args = <Object?>[];
    void match(String sql, Object value) { clauses.add(sql); args.add(value); }
    if (accountId != null) match('e.account_id = ?', accountId);
    if (fromDate != null) match('e.date >= ?', fromDate);
    if (toDate != null) match('e.date <= ?', toDate);
    if (category != null) match('$categoryName = ?', category);
    if (query.trim().isNotEmpty) {
      match('''(COALESCE(e.contact_name,'') || ' ' || COALESCE(e.contact_phone,'') || ' ' ||
        COALESCE(e.$note,'') || ' ' || $accountName || ' $prefix' || e.id || ' ' || $categoryName || ' ' || $mode) GLOB ?''',
        _searchPattern(query));
    }
    String where(List<String> filters) => filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final from = 'FROM $table e LEFT JOIN accounts a ON a.id=e.account_id';
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      final categories = (await txn.rawQuery('SELECT DISTINCT $categoryName AS name FROM $table e ORDER BY name'))
        .map((r) => r['name'] as String).toList();
      final totals = (await txn.rawQuery('''SELECT COUNT(*) AS count, TOTAL(ROUND(e.amount * 100)) AS paise
        $from ${where(clauses)}''', args)).single;
      final accounts = await txn.query('accounts', columns: ['id', 'name'], orderBy: 'name, id');
      final rows = await txn.rawQuery('''${_entriesSql(income)} $from ${where([
        ...clauses,
        if (after != null) '(e.date, $created, e.id) < (?, ?, ?)',
      ])} ORDER BY e.date DESC, $created DESC, e.id DESC LIMIT ?''', [
        ...args,
        if (after != null) ...[after.date, after.row['created_at'] ?? '', after.id],
        size + 1,
      ]);
      return HistoryPage(
        rows.take(size).map((r) => HistoryEntry(r, income: income)).toList(),
        rows.length > size,
        totals['count'] as int,
        (totals['paise'] as num).round(),
        categories,
        {for (final r in accounts) r['id'] as int: r['name'] as String},
      );
    });
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
