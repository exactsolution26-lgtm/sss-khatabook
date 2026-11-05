import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';

import 'account_controller.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../widgets/simple_button.dart';
import '../../widgets/simple_input.dart';

class OpeningBalanceScreen extends StatefulWidget {
  const OpeningBalanceScreen({super.key});

  @override
  State<OpeningBalanceScreen> createState() => _OpeningBalanceScreenState();
}

class _OpeningBalanceScreenState extends State<OpeningBalanceScreen> {
  final controller = AccountController();
  final cashController = TextEditingController();
  final bankController = TextEditingController();
  bool saving = false;
  DateTime? savedAt;
  String savedCash = '';
  String savedBank = '';

  @override
  void initState() {
    super.initState();
    cashController.addListener(clearConfirmation);
    bankController.addListener(clearConfirmation);
  }

  void clearConfirmation() {
    if (savedAt != null && (cashController.text != savedCash || bankController.text != savedBank)) {
      setState(() => savedAt = null);
    }
  }

  @override
  void dispose() {
    cashController.dispose();
    bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Opening Balance'),
      actions: [
        IconButton(
          tooltip: 'WhatsApp Sharing',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => Navigator.pushNamed(context, '/whatsapp/share'),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          SimpleInput(
            hintText: 'Cash opening balance',
            label: 'Cash opening balance (₹)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: cashController,
          ),
          const SizedBox(height: 16),
          SimpleInput(
            hintText: 'Bank opening balance',
            label: 'Bank opening balance (₹)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: bankController,
          ),
          const SizedBox(height: 24),
          SimpleButton(
            text: savedAt != null ? 'Saved ✓' : 'Save & Continue',
            isLoading: saving,
            onPressed: savedAt != null ? null : () async {
              if (saving) return;
              final cash = double.tryParse(cashController.text.trim());
              final bank = double.tryParse(bankController.text.trim());
              if (cash == null ||
                  bank == null ||
                  !cash.isFinite ||
                  !bank.isFinite ||
                  cash < 0 ||
                  bank < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: AppText('Enter valid non-negative balances'),
                  ),
                );
                return;
              }
              setState(() => saving = true);
              try {
                controller.cashOpeningBalance = cash;
                controller.bankOpeningBalance = bank;
                final cashText = cashController.text;
                final bankText = bankController.text;
                FocusScope.of(context).unfocus();
                final recordedAt = await controller.saveBalances();
                if (mounted) setState(() {
                  savedCash = cashText;
                  savedBank = bankText;
                  if (cashController.text == cashText && bankController.text == bankText) {
                    savedAt = recordedAt;
                  }
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: AppText('Opening balance saved')),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: AppText('Could not save balance')),
                );
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
          ),
          if (saving) const Padding(
            padding: EdgeInsets.all(12), child: Text('Saving…'),
          ),
          if (savedAt != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const AppText('Opening balance saved successfully'),
                  const SizedBox(height: 8),
                  Text('Cash: ₹$savedCash · Bank: ₹$savedBank'),
                  const SizedBox(height: 8),
                  Text(dates.DateUtils.formatIstDateTime(savedAt!)),
                ])),
            )),
          ),
        ],
      ),
    ),
  );
}
