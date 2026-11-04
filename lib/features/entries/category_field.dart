import 'package:flutter/material.dart';
import '../../database/db_helper.dart';

class CategoryField extends StatefulWidget {
  const CategoryField({super.key, required this.income, required this.onChanged,this.initialValue});
  final bool income;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<CategoryField> {
  late List<String> choices;
  String selected = 'Other';
  @override
  void initState() {
    super.initState();
    choices = widget.income
      ? ['Sales', 'Service Fees', 'Commission / Brokerage', 'Rent', 'Salary', 'Refund', 'Other']
      : ['Food', 'Groceries', 'Travel', 'Fuel', 'Rent', 'Utilities', 'Phone & Internet',
          'Office Expenses', 'Salaries', 'Advertising', 'Repairs', 'Medical',
          'Education', 'Bank Charges', 'Taxes', 'Other'];
    selected=(widget.initialValue?.trim().isNotEmpty ?? false) ? widget.initialValue!.trim() : 'Other';
    if(!choices.contains(selected)) choices.add(selected);
    load();
  }

  Future<void> load() async {
    try {
      final db = await DBHelper.database;
      final table = widget.income ? 'income' : 'expenses';
      final stored = await db.rawQuery('SELECT DISTINCT category FROM $table WHERE category IS NOT NULL');
      final custom = await db.query('entry_categories', where: 'kind = ?',
        whereArgs: [widget.income ? 'income' : 'expense']);
      final rows = [...stored, ...custom.map((row) => <String, Object?>{'category': row['name']})];
      if (!mounted) return;
      setState(() {
        for (final row in rows) {
          final value = (row['category'] as String).trim();
          if (value.isNotEmpty && !choices.any((c) => c.toLowerCase() == value.toLowerCase())) {
            choices.add(value);
          }
        }
      });
    } catch (_) {
      // Built-in options remain usable if category history cannot be read.
    }
  }

  Future<void> add() async {
    var typedName = ''; 
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add Category'),
      content: TextField(onChanged: (value) => typedName = value, maxLength: 60, autofocus: true,
        decoration: const InputDecoration(labelText: 'Category name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final value = typedName.trim();
          if (value.isNotEmpty && value.length <= 60) Navigator.pop(context, value);
        }, child: const Text('Add')),
      ],
    ));
    if (!mounted || value == null) return;
    try {
      final db = await DBHelper.database;
      await db.rawInsert('INSERT OR IGNORE INTO entry_categories(kind,name,created_at) VALUES(?,?,?)',
        [widget.income ? 'income' : 'expense', value, DateTime.now().toUtc().toIso8601String()]);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save category. Please retry.')));
      return;
    }
    if (!mounted) return;
    setState(() {
      final matches = choices.where((c) => c.toLowerCase() == value.toLowerCase());
      if (matches.isEmpty) choices.add(value);
      selected = matches.isEmpty ? value : matches.first;
    });
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(key: ValueKey(selected), initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [for (final name in choices) DropdownMenuItem(value: name, child: Text(name))],
        onChanged: (value) {
          if (value == null) return;
          setState(() => selected = value);
          widget.onChanged(value);
        }),
      Align(alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: add, icon: const Icon(Icons.add),
          label: const Text('Add Category'))),
    ],
  );
}
