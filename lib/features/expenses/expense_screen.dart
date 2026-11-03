import 'package:flutter/material.dart';

import 'expense_controller.dart';
import '../accounts/account_controller.dart';
import '../../models/account_model.dart';
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
  bool saving = false;
  List<AccountModel> accounts = [];
  int? accountId;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final loaded = await AccountController().getAllAccounts();
      if (!mounted) return;
      setState(() {
        accounts = loaded;
        accountId = loaded.isEmpty ? null : loaded.first.id;
        loadError = null;
      });
    } catch (_) {
      if (mounted) setState(() => loadError = 'Could not load accounts');
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Expense')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          if (loadError != null)
            TextButton(
              onPressed: _loadAccounts,
              child: Text('$loadError — Retry'),
            ),
          DropdownButtonFormField<int>(
            initialValue: accountId,
            decoration: const InputDecoration(labelText: 'Account'),
            items: accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: saving ? null : (id) => setState(() => accountId = id),
          ),
          if (accounts.isEmpty)
            const Text('Create an account before adding an expense.'),
          const SizedBox(height: 16),
          SimpleInput(
            hintText: 'Amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              if (value != null) setState(() => mode = value);
            },
          ),
          const SizedBox(height: 12),
          SimpleInput(hintText: 'Category', controller: categoryController),
          const SizedBox(height: 12),
          SimpleInput(hintText: 'Note (optional)', controller: noteController),
          const SizedBox(height: 24),
          SimpleButton(
            text: 'Save Expense',
            isLoading: saving,
            onPressed: () async {
              if (saving) return;
              if (accountId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select an account first')),
                );
                return;
              }
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || !amount.isFinite || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid positive amount'),
                  ),
                );
                return;
              }
              setState(() => saving = true);
              try {
                await controller.saveExpense(
                  ExpenseModel(
                    accountId: accountId,
                    amount: amount,
                    mode: mode,
                    category: categoryController.text.trim(),
                    note: noteController.text.trim(),
                    date: DateTime.now().toUtc().toIso8601String(),
                  ),
                );
                if (!mounted) return;
                amountController.clear();
                noteController.clear();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Expense saved')));
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not save expense')),
                );
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
          ),
        ],
      ),
    ),
  );
}
