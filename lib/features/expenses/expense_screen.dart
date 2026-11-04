import 'package:flutter/material.dart';

import 'expense_controller.dart';
import '../entries/attachments.dart';
import '../entries/attachment_widgets.dart';
import '../entries/contact_fields.dart';
import '../entries/category_field.dart';
import '../../core/utils/date_utils.dart' as dates;
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
  final categoryController = TextEditingController(text: 'Other');
  final contactName = TextEditingController();
  final contactPhone = TextEditingController();
  ExpenseModel? lastSaved;
  final attachments = ValueNotifier<List<PendingAttachment>>([]);
  DateTime selectedDate = dates.DateUtils.indiaToday();
  final noteController = TextEditingController();
  String mode = 'cash';
  bool saving = false;
  List<AccountModel> accounts = [];
  int? accountId;
  String? loadError;

  @override
  void initState() {
    super.initState();
    amountController.addListener(() {
      if (lastSaved != null && amountController.text.isNotEmpty) setState(() => lastSaved = null);
    });
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

  Future<void> selectDate() async {
    final selected = await showDatePicker(context: context, initialDate: selectedDate,
      firstDate: DateTime(2000), lastDate: dates.DateUtils.indiaToday());
    if (mounted && selected != null) setState(() => selectedDate = selected);
  }

  @override
  void dispose() {
    attachments.dispose();
    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();
    contactName.dispose();
    contactPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Expense')),
    body: AbsorbPointer(absorbing: saving, child: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          if (loadError != null)
            TextButton(
              onPressed: _loadAccounts,
              child: Text('$loadError — Retry'),
            ),
          DropdownButtonFormField<int>(
            key: ValueKey('expense-account-$accountId'),
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
          CategoryField(income: false, onChanged: (value) => categoryController.text = value),
          const SizedBox(height: 12),
          ContactFields(name: contactName, phone: contactPhone),
          const SizedBox(height: 12),
          SimpleInput(hintText: 'Note (optional)', controller: noteController),
          const SizedBox(height: 16),
          InkWell(onTap: saving ? null : selectDate,
            child: InputDecorator(decoration: const InputDecoration(
              labelText: 'Transaction date', suffixIcon: Icon(Icons.calendar_today)),
              child: Text(dates.DateUtils.formatDisplayDate(selectedDate)))),
          const SizedBox(height: 24),
          AttachmentPicker(selected: attachments),
          const SizedBox(height: 12),
          SimpleButton(
            text: lastSaved == null ? 'Save Expense' : 'Saved ✓',
            isLoading: saving,
            onPressed: lastSaved != null ? null : () async {
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
              FocusScope.of(context).unfocus();
              setState(() => saving = true);
              try {
                final recorded = await controller.saveExpense(
                  ExpenseModel(
                    accountId: accountId,
                    amount: amount,
                    mode: mode,
                    category: categoryController.text.trim(),
                    note: noteController.text.trim(),
                    date: dates.DateUtils.formatDate(selectedDate),
                    contactName: contactName.text, contactPhone: contactPhone.text,
                  ),
                  attachments: attachments.value,
                );
                if (!mounted) return;
                setState(() => lastSaved = recorded);
                attachments.value = [];
                amountController.clear();
                noteController.clear();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Expense saved')));
              } on ArgumentError {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a contact name and valid phone number, or leave both empty.')));
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
          if (lastSaved != null) Padding(padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Expense saved ✓ · ₹${lastSaved!.amount.toStringAsFixed(2)}'),
                  Text(lastSaved!.category),
                  if (lastSaved!.contactName != null) Text('${lastSaved!.contactName} · ${lastSaved!.contactPhone}'),
                  Text('Saved at: ${dates.DateUtils.formatIstDateTime(lastSaved!.createdAt!)}'),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AttachmentScreen(entryId: lastSaved!.id!, income: false))), child: const Text('View Attachments')),
                  TextButton(onPressed: () => setState(() => lastSaved = null), child: const Text('Add another entry')),
                ])),
            ))),
        ],
      ),
    )),
  );
}
