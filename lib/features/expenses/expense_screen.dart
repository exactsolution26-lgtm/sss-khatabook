import 'package:flutter/material.dart';
import 'expense_controller.dart';
import '../../models/expense_model.dart';
import '../../widgets/simple_button.dart';
import '../../widgets/simple_input.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/validation_utils.dart';
import '../accounts/account_controller.dart';
import '../../models/account_model.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final controller = ExpenseController();
  final _accountController = AccountController();
  final amountController = TextEditingController();
  final categoryController = TextEditingController();
  final noteController = TextEditingController();

  String mode = 'cash';
  bool _isSaving = false;
  AccountModel? _account;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final accounts = await _accountController.getAllAccounts();
    if (accounts.isNotEmpty) {
      setState(() => _account = accounts.first);
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final expense = ExpenseModel(
        accountId: _account?.id,
        amount: double.tryParse(amountController.text) ?? 0,
        mode: mode,
        category: categoryController.text.trim().isEmpty
            ? null
            : categoryController.text.trim(),
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        date: AppDateUtils.formatDate(DateTime.now()),
      );

      await controller.saveExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.expenseSaved)),
        );
        amountController.clear();
        categoryController.clear();
        noteController.clear();
        setState(() => mode = 'cash');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addExpense)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SimpleInput(
                label: AppStrings.amount,
                keyboardType: TextInputType.number,
                controller: amountController,
                validator: ValidationUtils.validateAmount,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(
                  labelText: 'Mode',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 16),
              SimpleInput(
                label: AppStrings.description,
                keyboardType: TextInputType.text,
                controller: categoryController,
              ),
              const SizedBox(height: 16),
              SimpleInput(
                label: '${AppStrings.description} ${AppStrings.optional}',
                keyboardType: TextInputType.text,
                controller: noteController,
                maxLines: 2,
              ),
              const Spacer(),
              SimpleButton(
                text: AppStrings.saveExpense,
                onPressed: _isSaving ? null : _saveExpense,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
