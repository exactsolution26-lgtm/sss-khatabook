import 'package:flutter/material.dart';
import '../../core/localization/app_text.dart';
import '../../database/db_helper.dart';

const _expenseCategoryIcons = {
  'Food': 'food',
  'Groceries': 'groceries',
  'Travel': 'travel',
  'Fuel': 'fuel',
  'Rent': 'rent',
  'Utilities': 'utilities',
  'Phone & Internet': 'phone_internet',
  'Office Expenses': 'office_expenses',
  'Salaries': 'salaries',
  'Advertising': 'advertising',
  'Repairs': 'repairs',
  'Medical': 'medical',
  'Education': 'education',
  'Bank Charges': 'bank_charges',
  'Taxes': 'taxes',
  'Other': 'other',
};

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
      : _expenseCategoryIcons.keys.toList();
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

  void select(String value) {
    setState(() => selected = value);
    widget.onChanged(value);
  }

  Widget _expenseIcon(String name) {
    final asset = _expenseCategoryIcons[name] ?? 'other';
    return Image.asset(
      'assets/expense_categories/$asset.webp',
      width: 48,
      height: 34,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }

  Future<void> _pickExpenseCategory() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: AppText('Select category',
                    style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: choices.length,
                    itemBuilder: (context, index) {
                      final name = choices[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        selected: name == selected,
                        selectedTileColor: colors.secondaryContainer,
                        selectedColor: colors.onSecondaryContainer,
                        leading: _expenseIcon(name),
                        title: Text(name),
                        trailing: name == selected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.pop(context, name),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted && value != null) select(value);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.income)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: _pickExpenseCategory,
          child: Row(
            children: [
              _expenseIcon(selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Category'),
                    Text(selected),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        )
      else
        DropdownButtonFormField<String>(key: ValueKey(selected), initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [for (final name in choices) DropdownMenuItem(value: name, child: Text(name))],
        onChanged: (value) {
          if (value == null) return;
          select(value);
        }),
      Align(alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: add, icon: const Icon(Icons.add),
          label: const Text('Add Category'))),
    ],
  );
}
