import 'package:flutter/material.dart';
import 'account_controller.dart';
import '../../core/utils/money.dart';
import '../../routes/app_routes.dart';
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
            TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.dashboardSelection,
              ),
              child: const Text('Choose Dashboard'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.addExpense),
              child: const Text('Add Expense'),
            ),
            const SizedBox(height: 8),
            SimpleButton(
              text: 'Save & Continue',
              onPressed: () async {
                Money cash;
                Money bank;
                try {
                  cash = Money.parseRupees(cashController.text.trim().isEmpty
                      ? '0'
                      : cashController.text);
                  bank = Money.parseRupees(bankController.text.trim().isEmpty
                      ? '0'
                      : bankController.text);
                } on FormatException catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                  return;
                }

                // Legacy SQLite schema uses REAL pending migration.
                controller.cashOpeningBalance = cash.paise / 100;
                controller.bankOpeningBalance = bank.paise / 100;
                try {
                  await controller.saveBalances();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening balance saved successfully'),
                    ),
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not save opening balance. Please retry.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
