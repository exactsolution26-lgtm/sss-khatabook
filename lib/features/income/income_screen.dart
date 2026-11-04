import 'package:flutter/material.dart';

import '../../widgets/header_text.dart';
import '../../widgets/simple_input.dart';
import '../../widgets/simple_button.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/calculation_utils.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/utils/date_utils.dart' as khata_dates;
import 'income_controller.dart';
import '../entries/attachments.dart';
import '../entries/attachment_widgets.dart';
import '../entries/contact_fields.dart';
import '../entries/category_field.dart';
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
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String _category = 'Other';
  String _mode = 'cash';
  IncomeModel? _lastSaved;
  final attachments = ValueNotifier<List<PendingAttachment>>([]);
  final _accountController = AccountController();

  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  DateTime _selectedDate = khata_dates.DateUtils.indiaToday();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      if (_lastSaved != null && _amountController.text.isNotEmpty) setState(() => _lastSaved = null);
    });
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountController.getAllAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        if (accounts.isNotEmpty && _selectedAccount == null) {
          _selectedAccount = accounts.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not load accounts'),
          action: SnackBarAction(label: 'Retry', onPressed: _loadAccounts),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: khata_dates.DateUtils.indiaToday(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveIncome() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.selectAccount)));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final income = IncomeModel(
        accountId: _selectedAccount!.id!,
        amount: CalculationUtils.parseAmount(_amountController.text),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: _selectedDate,
        createdAt: DateTime.now().toUtc(),
        category: _category, mode: _mode,
        contactName: _contactName.text, contactPhone: _contactPhone.text,
      );

      final id = await _incomeController.createIncome(income, attachments: attachments.value);
      final recorded = await _incomeController.getIncomeById(id);

      if (mounted) {
        setState(() => _lastSaved = recorded);
        attachments.value = [];
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.incomeSaved)));
        _amountController.clear();
        _descriptionController.clear();
      }
    } on ArgumentError {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a contact name and valid phone number, or leave both empty.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save income. Please retry.')),
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
    attachments.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addIncome)),
      body: AbsorbPointer(absorbing: _isLoading, child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const HeaderText(text: AppStrings.addIncome),
              const SizedBox(height: 24),
              DropdownButtonFormField<AccountModel>(
                key: ValueKey('income-account-${_selectedAccount?.id}'),
                initialValue: _selectedAccount,
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: ValidationUtils.validateAmount,
              ),
              const SizedBox(height: 16),
              CategoryField(income: true, onChanged: (value) => _category = value),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Payment mode'),
                items: const [DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'online', child: Text('Online'))],
                onChanged: (value) { if (value != null) setState(() => _mode = value); }),
              const SizedBox(height: 16),
              ContactFields(name: _contactName, phone: _contactPhone),
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
                  child: Text(
                    khata_dates.DateUtils.formatDisplayDate(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AttachmentPicker(selected: attachments),
              const SizedBox(height: 12),
              SimpleButton(
                text: _lastSaved == null ? AppStrings.saveIncome : 'Saved ✓',
                onPressed: _isLoading || _lastSaved != null ? null : _saveIncome,
                isLoading: _isLoading,
              ),
              if (_lastSaved != null) Padding(padding: const EdgeInsets.only(top: 16),
                child: Semantics(liveRegion: true, child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Income saved ✓ · ₹${_lastSaved!.amount.toStringAsFixed(2)}'),
                      Text(_lastSaved!.category ?? ''),
                      if (_lastSaved!.contactName != null) Text('${_lastSaved!.contactName} · ${_lastSaved!.contactPhone}'),
                      Text('Saved at: ${khata_dates.DateUtils.formatIstDateTime(_lastSaved!.createdAt)}'),
                      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AttachmentScreen(entryId: _lastSaved!.id!, income: true))), child: const Text('View Attachments')),
                      TextButton(onPressed: () => setState(() => _lastSaved = null), child: const Text('Add another entry')),
                    ])),
                ))),
            ],
          ),
        ),
      )),
    );
  }
}
