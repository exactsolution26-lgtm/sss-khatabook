import 'package:flutter/material.dart';

import 'whatsapp_share_service.dart';

class VerifiedShareScreen extends StatefulWidget {
  const VerifiedShareScreen({super.key, required this.draft});
  final WhatsAppDraft draft;
  @override
  State<VerifiedShareScreen> createState() => _VerifiedShareScreenState();
}

class _VerifiedShareScreenState extends State<VerifiedShareScreen> {
  final phone = TextEditingController();
  final service = const WhatsAppShareService();
  late Future<WhatsAppDraft> preview;
  bool optedIn = false;
  bool busy = false;
  bool phoneEdited = false;
  String? error;
  @override
  void initState() {
    super.initState();
    preview = resolve();
  }
  Future<WhatsAppDraft> resolve() async {
    final result = await service.resolveDraft(widget.draft);
    if (mounted && !phoneEdited && result.recipientPhone != null) phone.text = result.recipientPhone!;
    return result;
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> share() async {
    if (!optedIn || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final shown = await preview;
      final opened = await service.openDraft(phone.text, widget.draft, expectedMessage: shown.message);
      if (!mounted) return;
      if (!opened) throw StateError('WhatsApp could not open');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft opened. Review and confirm Send in WhatsApp.'),
        ),
      );
    } catch (_) {
      if (mounted)
        setState(
          () {
            preview = resolve(); optedIn = false;
            error = 'Review the current record and phone number, then select Share again.';
          },
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share recorded ledger')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        FutureBuilder<WhatsAppDraft>(
          future: preview,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text(
                'This financial record could not be verified. Sharing is unavailable.',
              );
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(snapshot.data!.message),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: phone,
          onChanged: (_) => phoneEdited = true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'WhatsApp number'),
        ),
        CheckboxListTile(
          value: optedIn,
          onChanged: busy ? null : (v) => setState(() => optedIn = v ?? false),
          title: const Text('Share via WhatsApp'),
          subtitle: const Text(
            'Optional. The current ledger is checked again before opening.',
          ),
        ),
        if (error != null) Text(error!),
        FilledButton(
          onPressed: optedIn && !busy ? share : null,
          child: Text(busy ? 'Checking record…' : 'Open WhatsApp Draft'),
        ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
      ],
    ),
  );
}
