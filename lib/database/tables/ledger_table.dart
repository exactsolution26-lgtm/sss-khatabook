import '../db_helper.dart';

class LedgerSummary {
  const LedgerSummary({required this.incomePaise, required this.expensePaise,
    required this.cashPaise, required this.bankPaise});
  final int incomePaise;
  final int expensePaise;
  final int cashPaise;
  final int bankPaise;
  int get totalPaise => cashPaise + bankPaise;
}

class LedgerTable {
  static Future<void> recordIncome({
    required String amountText,
    required String category,
    required String party,
    required String paymentMode,
    String note = '',
  }) async {
    // Money parsing is performed before any database writes.
    final amount = _amountPaise(amountText);
    if (amount <= 0 || category.trim().isEmpty || party.trim().isEmpty) {
      throw ArgumentError('Amount, category and party are required');
    }
    if (!['cash', 'upi', 'bank'].contains(paymentMode)) {
      throw ArgumentError('Invalid payment mode');
    }
    final account = paymentMode == 'cash' ? 'local-cash' : 'local-bank';
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await DBHelper.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': 'income-${DateTime.now().microsecondsSinceEpoch}',
        'business_id': 'local-demo',
        'account_id': account,
        'type': 'income',
        'amount_paise': amount,
        'category': category.trim(),
        'party_name': party.trim(),
        'payment_mode': paymentMode,
        'note': note.trim(),
        'occurred_at_utc': now,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      final count = await txn.rawUpdate(
        'UPDATE accounts SET balance_paise = balance_paise + ? WHERE id = ? AND business_id = ?',
        [amount, account, 'local-demo'],
      );
      if (count != 1) throw StateError('Account not found');
    });
  }

  static int _amountPaise(String text) {
    final input = text.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(input)) {
      throw const FormatException('Enter an amount with at most two decimals');
    }
    final parts = input.split('.');
    final whole = int.parse(parts[0]);
    final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
    const max = 9223372036854775807;
    if (whole > (max - fraction) ~/ 100) throw const FormatException('Amount too large');
    return whole * 100 + fraction;
  }

  static Future<LedgerSummary> summary({required String businessId}) async {
    if (businessId.trim().isEmpty) throw ArgumentError('Business ID required');
    final db = await DBHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount_paise ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount_paise ELSE 0 END), 0) AS expense
      FROM transactions WHERE business_id = ?
    ''', [businessId]);
    final accounts = await db.query('accounts',
        columns: ['id', 'balance_paise'], where: 'business_id = ?', whereArgs: [businessId]);
    int balance(String id) => (accounts.firstWhere((row) => row['id'] == id)['balance_paise'] as int);
    return LedgerSummary(
      incomePaise: rows.first['income'] as int,
      expensePaise: rows.first['expense'] as int,
      cashPaise: balance('local-cash'),
      bankPaise: balance('local-bank'),
    );
  }
}
