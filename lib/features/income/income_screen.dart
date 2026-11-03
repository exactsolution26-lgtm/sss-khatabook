import 'package:flutter/material.dart';
import '../../database/tables/ledger_table.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});
  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final amount = TextEditingController();
  final category = TextEditingController();
  final party = TextEditingController();
  final note = TextEditingController();
  String paymentMode = 'cash';
  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    category.dispose();
    party.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await LedgerTable.recordIncome(
        amountText: amount.text,
        category: category.text,
        party: party.text,
        paymentMode: paymentMode,
        note: note.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Income saved')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save income: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Income')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount (INR)')),
      TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
      TextField(controller: party, decoration: const InputDecoration(labelText: 'Received from (Party)')),
      DropdownButtonFormField<String>(
        value: paymentMode,
        decoration: const InputDecoration(labelText: 'Payment mode'),
        items: const [
          DropdownMenuItem(value: 'cash', child: Text('Cash')),
          DropdownMenuItem(value: 'upi', child: Text('UPI')),
          DropdownMenuItem(value: 'bank', child: Text('Bank')),
        ],
        onChanged: saving ? null : (value) => setState(() => paymentMode = value ?? 'cash'),
      ),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Purpose / note')),
      const SizedBox(height: 24),
      FilledButton(onPressed: saving ? null : save,
        child: Text(saving ? 'Saving...' : 'Save Income')),
    ]),
  );
}
