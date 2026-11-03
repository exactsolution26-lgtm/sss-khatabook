import 'package:flutter/material.dart';
import 'account_controller.dart';
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

  @override
  void dispose() {
    cashController.dispose();
    bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Opening Balance'), actions: [
      IconButton(tooltip: 'WhatsApp Sharing', icon: const Icon(Icons.share_outlined),
        onPressed: () => Navigator.pushNamed(context, '/whatsapp/share')),
    ]),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        SimpleInput(
          hintText: 'Cash opening balance',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: cashController,
        ),
        const SizedBox(height: 16),
        SimpleInput(
          hintText: 'Bank opening balance',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: bankController,
        ),
        const Spacer(),
        SimpleButton(
          text: 'Save & Continue',
          isLoading: saving,
          onPressed: () async {
            final cash = double.tryParse(cashController.text.trim());
            final bank = double.tryParse(bankController.text.trim());
            if (cash == null || bank == null ||
                !cash.isFinite || !bank.isFinite || cash < 0 || bank < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter valid non-negative balances')),
              );
              return;
            }
            setState(() => saving = true);
            try {
              controller.cashOpeningBalance = cash;
              controller.bankOpeningBalance = bank;
              await controller.saveBalances();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening balance saved')),
              );
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save balance')),
              );
            } finally {
              if (mounted) setState(() => saving = false);
            }
          },
        ),
      ]),
    ),
  );
}
