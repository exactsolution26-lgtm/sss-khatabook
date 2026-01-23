import 'package:flutter/material.dart';
import 'expense_controller.dart';
import '../../models/expense_model.dart';
import '../../widgets/simple_button.dart';
import '../../widgets/simple_input.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final controller = ExpenseController();

  final amountController = TextEditingController();
  final categoryController = TextEditingController();
  final noteController = TextEditingController();

  String mode = 'cash';

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SimpleInput(
              hintText: 'Amount',
              keyboardType: TextInputType.number,
              controller: amountController,
            ),
            const SizedBox(height: 12),

            DropdownButton<String>(
              value: mode,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
              ],
              onChanged: (value) {
                setState(() {
                  mode = value!;
                });
              },
            ),

            const SizedBox(height: 12),
            SimpleInput(
              hintText: 'Category',
              keyboardType: TextInputType.text,
              controller: categoryController,
            ),

            const SizedBox(height: 12),
            SimpleInput(
              hintText: 'Note (optional)',
              keyboardType: TextInputType.text,
              controller: noteController,
            ),

            const Spacer(),
            SimpleButton(
              text: 'Save Expense',
              onPressed: () async {
                final expense = ExpenseModel(
                  amount: double.tryParse(amountController.text) ?? 0,
                  mode: mode,
                  category: categoryController.text,
                  note: noteController.text,
                  date: DateTime.now().toString(),
                );

                await controller.saveExpense(expense);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense saved')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
