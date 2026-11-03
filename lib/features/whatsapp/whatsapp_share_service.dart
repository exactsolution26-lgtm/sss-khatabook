import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum WhatsAppMessageType {
  ledger, reminder, receipt, monthlyStatement, subscription, custom
}

class WhatsAppDraft {
  const WhatsAppDraft({
    required this.type, required this.customer, required this.amount,
    required this.timestampUtc, this.details = '', this.month = '',
  });
  final WhatsAppMessageType type;
  final String customer;
  final double amount;
  final DateTime timestampUtc;
  final String details;
  final String month;

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
        return 'Hello $name, payment of $money has been recorded. Please verify your receipt in SSS Khatabook.\n$stamp IST';
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
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final number = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2) : digits;
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(number)) {
      throw FormatException('Enter a valid 10-digit Indian mobile number');
    }
    return '91$number';
  }

  static Uri buildLink(String phone, String message) {
    final number = normalizeIndianPhone(phone);
    if (message.trim().isEmpty) throw ArgumentError('Message is empty');
    return Uri.https('wa.me', '/$number', {'text': message});
  }

  /// Opens a user-confirmed WhatsApp draft. Never claims delivery.
  Future<bool> openDraft(String phone, WhatsAppDraft draft) async {
    if (draft.customer.trim().isEmpty) {
      throw ArgumentError('Customer name is required');
    }
    if (!draft.amount.isFinite || draft.amount < 0) {
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
    entries.add(jsonEncode({
      'type': draft.type.name,
      'opened_at_utc': DateTime.now().toUtc().toIso8601String(),
      'message_timestamp_ist': WhatsAppDraft.formatIst(draft.timestampUtc),
      'status': 'opened_not_confirmed_sent',
    }));
    await prefs.setStringList('whatsapp_draft_audit_v1',
        entries.length > 500 ? entries.sublist(entries.length - 500) : entries);
  }
}
