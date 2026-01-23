import 'package:flutter/material.dart';
import '../../widgets/header_text.dart';
import '../../widgets/simple_input.dart';
import '../../widgets/simple_button.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/calculation_utils.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/utils/date_utils.dart';
import 'income_controller.dart';
import '../../models/income_model.dart';
import '../../features/accounts/account_controller.dart';
import '../../models/account_model.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _incomeController = IncomeController();
  final _accountController = AccountController();
  
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _accountController.getAllAccounts();
    setState(() {
      _accounts = accounts;
      if (accounts.isNotEmpty && _selectedAccount == null) {
        _selectedAccount = accounts.first;
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectAccount)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final income = IncomeModel(
        accountId: _selectedAccount!.id!,
        amount: CalculationUtils.parseAmount(_amountController.text),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: _selectedDate,
        createdAt: DateTime.now(),
      );

      await _incomeController.createIncome(income);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.incomeSaved)),
        );
        _amountController.clear();
        _descriptionController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.addIncome),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeaderText(text: AppStrings.addIncome),
              const SizedBox(height: 24),
              DropdownButtonFormField<AccountModel>(
                value: _selectedAccount,
                decoration: const InputDecoration(
                  labelText: AppStrings.account,
                  border: OutlineInputBorder(),
                ),
                items: _accounts.map((account) {
                  return DropdownMenuItem(
                    value: account,
                    child: Text(account.name),
                  );
                }).toList(),
                onChanged: (account) {
                  setState(() => _selectedAccount = account);
                },
              ),
              const SizedBox(height: 16),
              SimpleInput(
                controller: _amountController,
                label: AppStrings.amount,
                keyboardType: TextInputType.number,
                validator: ValidationUtils.validateAmount,
              ),
              const SizedBox(height: 16),
              SimpleInput(
                controller: _descriptionController,
                label: '${AppStrings.description} ${AppStrings.optional}',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: AppStrings.date,
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateUtils.formatDisplayDate(_selectedDate)),
                ),
              ),
              const SizedBox(height: 24),
              SimpleButton(
                text: AppStrings.saveIncome,
                onPressed: _isLoading ? null : _saveIncome,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
