import 'dart:convert';

import '../../database/db_helper.dart';
import '../entries/party_snapshot.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum WhatsAppMessageType {
  ledger,
  reminder,
  receipt,
  monthlyStatement,
  subscription,
  custom,
}

class WhatsAppDraft {
  const WhatsAppDraft({
    required this.type,
    required this.customer,
    required this.amount,
    required this.timestampUtc,
    this.details = '',
    this.month = '',
    this.sourceAccountId,
    this.sourceIncomeId,
    this.sourceExpenseId,
    this.recipientPhone,
  });
  final WhatsAppMessageType type;
  final String customer;
  final double amount;
  final DateTime timestampUtc;
  final String details;
  final String month;
  final int? sourceAccountId;
  final int? sourceIncomeId;
  final int? sourceExpenseId;
  final String? recipientPhone;

  String get message {
    final name = customer.trim();
    final money = '₹${amount.toStringAsFixed(2)}';
    final stamp = formatIst(timestampUtc);
    switch (type) {
      case WhatsAppMessageType.ledger:
        return 'Hello $name, your SSS Khatabook ledger summary is $money.\n$details\nGenerated: $stamp IST';
      case WhatsAppMessageType.reminder:
        return 'Hello $name, this is a reminder of your pending balance of $money. Please verify your ledger.\n$stamp IST';
      case WhatsAppMessageType.receipt:
        return sourceIncomeId == null && sourceExpenseId == null
            ? 'Unverified receipt draft. Select a recorded income transaction before sharing.\n$stamp IST'
            : 'Hello $name, recorded ${sourceExpenseId == null ? 'payment receipt #$sourceIncomeId' : 'expense #$sourceExpenseId'}: $money.\n$details\n$stamp IST';
      case WhatsAppMessageType.monthlyStatement:
        return 'Hello $name, your SSS Khatabook statement for $month:\n$details\nGenerated: $stamp IST';
      case WhatsAppMessageType.subscription:
        return 'Hello $name, your SSS Khatabook subscription update: $details\n$stamp IST';
      case WhatsAppMessageType.custom:
        return details;
    }
  }

  static String formatIst(DateTime utc) {
    final ist = utc.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(ist.day)}/${two(ist.month)}/${ist.year} '
        '${two(ist.hour)}:${two(ist.minute)}:${two(ist.second)}';
  }
}

class WhatsAppShareService {
  const WhatsAppShareService();

  static String normalizeIndianPhone(String input) {
    if (!RegExp(r'^[+0-9\s()-]+$').hasMatch(input.trim())) {
      throw FormatException('Enter a valid Indian mobile number');
    }
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final number = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2)
        : digits;
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(number)) {
      throw FormatException('Enter a valid 10-digit Indian mobile number');
    }
    return '91$number';
  }

  static Uri buildLink(String phone, String message) {
    String number;
    try {number = PartySnapshot.optional('Recipient', phone)!.phone.substring(1);}
    catch (_) {throw const FormatException('Enter a valid phone number, with country code for international contacts');}
    if (message.trim().isEmpty || message.length > 4000) {
      throw ArgumentError('Message must contain 1 to 4000 characters');
    }
    return Uri.https('wa.me', '/$number', {'text': message});
  }

  /// Resolve financial messages from current local records, never free text.
  Future<WhatsAppDraft> resolveDraft(WhatsAppDraft draft) async {
    if (![
      WhatsAppMessageType.receipt,
      WhatsAppMessageType.ledger,
      WhatsAppMessageType.monthlyStatement,
    ].contains(draft.type))
      return draft;
    final db = await DBHelper.database;
    return db.transaction((txn) async {
      if (draft.type == WhatsAppMessageType.receipt) {
        if ((draft.sourceIncomeId == null) == (draft.sourceExpenseId == null)) {
          throw StateError('Choose exactly one recorded transaction');
        }
        final income = draft.sourceIncomeId != null;
        final table = income ? 'income' : 'expenses';
        final column = income ? 'income_id' : 'expense_id';
        final rows = await txn.rawQuery(
          'SELECT e.id,e.account_id,e.amount,e.date,e.created_at,e.contact_name,e.contact_phone,a.name '
          'FROM $table e JOIN accounts a ON a.id=e.account_id WHERE e.id=? '
          '${draft.sourceAccountId == null ? '' : 'AND e.account_id=? '}'
          'AND NOT EXISTS(SELECT 1 FROM payment_allocations p WHERE p.$column=e.id AND p.reversed_at IS NOT NULL)',
          [draft.sourceIncomeId ?? draft.sourceExpenseId, if (draft.sourceAccountId != null) draft.sourceAccountId],
        );
        if (rows.length != 1) throw StateError('Recorded payment not found');
        final row = rows.single;
        return WhatsAppDraft(
          type: draft.type,
          customer: (row['contact_name'] as String?)?.trim().isNotEmpty == true
              ? row['contact_name'] as String : row['name'] as String,
          amount: (row['amount'] as num).toDouble(),
          timestampUtc: DateTime.parse(row['created_at'] as String).toUtc(),
          details: 'Recorded date: ${row['date']}',
          sourceIncomeId: draft.sourceIncomeId,
          sourceExpenseId: draft.sourceExpenseId,
          sourceAccountId: row['account_id'] as int,
          recipientPhone: row['contact_phone'] as String?,
        );
      }
      if (draft.sourceAccountId == null)
        throw StateError('Choose an account ledger');
      final accounts = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [draft.sourceAccountId],
      );
      if (accounts.length != 1) throw StateError('Account not found');
      final account = accounts.single;
      String dateClause = '';
      final args = <Object?>[draft.sourceAccountId];
      if (draft.type == WhatsAppMessageType.monthlyStatement) {
        if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(draft.month))
          throw ArgumentError('Select statement month YYYY-MM');
        dateClause = ' AND substr(date,1,7) = ?';
        args.add(draft.month);
      }
      final incoming = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS total FROM income WHERE account_id = ?$dateClause',
        args,
      );
      final outgoing = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS total FROM expenses WHERE account_id = ?$dateClause',
        args,
      );
      final income = (incoming.single['total'] as num).toDouble();
      final expense = (outgoing.single['total'] as num).toDouble();
      final opening = (account['opening_balance'] as num).toDouble();
      final monthly = draft.type == WhatsAppMessageType.monthlyStatement;
      return WhatsAppDraft(
        type: draft.type,
        customer: account['name'] as String,
        amount: monthly ? income - expense : opening + income - expense,
        timestampUtc: draft.timestampUtc,
        month: draft.month,
        sourceAccountId: draft.sourceAccountId,
        details:
            '${monthly ? 'Period totals' : 'All-time totals'}: Income ₹${income.toStringAsFixed(2)}, Expenses ₹${expense.toStringAsFixed(2)}.${monthly ? '' : ' Opening ₹${opening.toStringAsFixed(2)}.'}',
      );
    });
  }

  /// Opens a user-confirmed WhatsApp draft. Never claims delivery.
  Future<bool> openDraft(String phone, WhatsAppDraft requested, {String? expectedMessage}) async {
    final draft = await resolveDraft(requested);
    if (expectedMessage != null && expectedMessage != draft.message) {
      throw StateError('Financial record changed; review the preview again');
    }
    if (draft.customer.trim().isEmpty) {
      throw ArgumentError('Customer name is required');
    }
    if (!draft.amount.isFinite ||
        (draft.amount < 0 &&
            draft.type != WhatsAppMessageType.ledger &&
            draft.type != WhatsAppMessageType.monthlyStatement)) {
      throw ArgumentError('Amount must be finite and non-negative');
    }
    final uri = buildLink(phone, draft.message);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      // Audit persistence must never turn an opened draft into a false failure.
      try {
        await _recordDraft(draft);
      } catch (_) {
        // WhatsApp launch already succeeded; local audit is best-effort.
      }
    }
    return opened;
  }

  Future<void> _recordDraft(WhatsAppDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('whatsapp_draft_audit_v1') ?? [];
    entries.add(
      jsonEncode({
        'type': draft.type.name,
        'opened_at_utc': DateTime.now().toUtc().toIso8601String(),
        'message_timestamp_ist': WhatsAppDraft.formatIst(draft.timestampUtc),
        'status': 'opened_not_confirmed_sent',
      }),
    );
    await prefs.setStringList(
      'whatsapp_draft_audit_v1',
      entries.length > 500 ? entries.sublist(entries.length - 500) : entries,
    );
  }
}
