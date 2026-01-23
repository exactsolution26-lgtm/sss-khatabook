import 'package:flutter/material.dart';
import 'account_controller.dart';
import '../../widgets/simple_button.dart';
import '../../widgets/simple_input.dart';

class OpeningBalanceScreen extends StatefulWidget {
  const OpeningBalanceScreen({super.key});

  @override
  State<OpeningBalanceScreen> createState() =>
      _OpeningBalanceScreenState();
}

class _OpeningBalanceScreenState extends State<OpeningBalanceScreen> {
  final controller = AccountController();

  final cashController = TextEditingController();
  final bankController = TextEditingController();

  @override
  void dispose() {
    cashController.dispose();
    bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opening Balance')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SimpleInput(
              hintText: 'Cash opening balance',
              keyboardType: TextInputType.number,
              controller: cashController,
            ),
            const SizedBox(height: 16),
            SimpleInput(
              hintText: 'Bank opening balance',
              keyboardType: TextInputType.number,
              controller: bankController,
            ),
            const Spacer(),
            SimpleButton(
              text: 'Save & Continue',
              onPressed: () async {
                controller.cashOpeningBalance =
                    double.tryParse(cashController.text) ?? 0;
                controller.bankOpeningBalance =
                    double.tryParse(bankController.text) ?? 0;

                await controller.saveBalances();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening balance saved successfully'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
