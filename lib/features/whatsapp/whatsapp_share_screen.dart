import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';

import 'whatsapp_share_service.dart';
import '../entries/contact_fields.dart';

class WhatsAppShareScreen extends StatefulWidget {
  const WhatsAppShareScreen({super.key,this.initialMessage});
  final String? initialMessage;
  @override
  State<WhatsAppShareScreen> createState() => _WhatsAppShareScreenState();
}

class _WhatsAppShareScreenState extends State<WhatsAppShareScreen> {
  final customer = TextEditingController();
  final phone = TextEditingController();
  final amount = TextEditingController(text: '0');
  final details = TextEditingController();
  final month = TextEditingController();
  WhatsAppMessageType type = WhatsAppMessageType.reminder;
  bool optedIn = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if(widget.initialMessage!=null){type=WhatsAppMessageType.custom;details.text=widget.initialMessage!;}
  }

  @override
  void dispose() {
    customer.dispose();
    phone.dispose();
    amount.dispose();
    details.dispose();
    month.dispose();
    super.dispose();
  }

  WhatsAppDraft draft() => WhatsAppDraft(
    type: type,
    customer: customer.text,
    amount: double.tryParse(amount.text) ?? 0,
    timestampUtc: DateTime.now().toUtc(),
    details: details.text,
    month: month.text,
  );

  Future<void> share() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!optedIn) throw StateError('Select Share via WhatsApp first');
      if (customer.text.trim().isEmpty)
        throw ArgumentError('Customer name required');
      final value = double.tryParse(amount.text);
      if (value == null || !value.isFinite || value < 0) {
        throw ArgumentError('Enter a valid amount');
      }
      final opened = await const WhatsAppShareService().openDraft(
        phone.text,
        draft(),
      );
      if (!opened) throw StateError('Unable to open WhatsApp');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Draft opened. Confirm Send in WhatsApp.'),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('WhatsApp Sharing')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<WhatsAppMessageType>(
          initialValue: type,
          decoration: const InputDecoration(label: AppText('Message Type')),
          items: WhatsAppMessageType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(switch (t) {
                    WhatsAppMessageType.ledger => 'Ledger Summary',
                    WhatsAppMessageType.reminder => 'Payment Reminder',
                    WhatsAppMessageType.receipt => 'Transaction Receipt',
                    WhatsAppMessageType.monthlyStatement => 'Monthly Statement',
                    WhatsAppMessageType.subscription => 'Subscription Reminder',
                    WhatsAppMessageType.custom => 'Custom Message',
                  }),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => type = value);
          },
        ),
        ContactFields(name: customer, phone: phone, onChanged: () => setState(() {})),
        if (type != WhatsAppMessageType.custom)
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(label: AppText('Amount (INR)')),
            onChanged: (_) => setState(() {}),
          ),
        if (type == WhatsAppMessageType.monthlyStatement)
          TextField(
            controller: month,
            decoration: const InputDecoration(label: AppText('Statement Month')),
            onChanged: (_) => setState(() {}),
          ),
        if (type == WhatsAppMessageType.custom ||
            type == WhatsAppMessageType.ledger ||
            type == WhatsAppMessageType.monthlyStatement ||
            type == WhatsAppMessageType.subscription)
          TextField(
            controller: details,
            maxLines: 4,
            decoration: const InputDecoration(label: AppText('Message Details')),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 16),
        if ([
          WhatsAppMessageType.receipt,
          WhatsAppMessageType.ledger,
          WhatsAppMessageType.monthlyStatement,
        ].contains(type))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: AppText('Open an account ledger to share a statement or receipt from recorded transactions. Manual financial drafts cannot be shared.',
            ),
          ),
        const AppText('Message Preview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SelectableText(draft().message),
        CheckboxListTile(
          value: optedIn,
          onChanged: (v) => setState(() => optedIn = v ?? false),
          title: const AppText('Share via WhatsApp'),
          subtitle: const AppText('Optional. You must confirm Send in WhatsApp.'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          onPressed:
              optedIn &&
                  !busy &&
                  ![
                    WhatsAppMessageType.receipt,
                    WhatsAppMessageType.ledger,
                    WhatsAppMessageType.monthlyStatement,
                  ].contains(type)
              ? share
              : null,
          icon: const Icon(Icons.send),
          label: const AppText('Open WhatsApp Draft'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('Skip'),
        ),
      ],
    ),
  );
}
