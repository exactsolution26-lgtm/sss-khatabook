import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import 'subscriber_repository.dart';

class BillingAdminScreen extends StatefulWidget {
  const BillingAdminScreen({super.key, required this.repository});

  final SubscriberRepository repository;

  @override
  State<BillingAdminScreen> createState() => _BillingAdminScreenState();
}

class _BillingAdminScreenState extends State<BillingAdminScreen> {
  late var billing = widget.repository.billingOverview();

  void refresh() => setState(() => billing = widget.repository.billingOverview());

  Future<void> edit(Map<String, dynamic> plan) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditPlan(repository: widget.repository, plan: plan),
    );
    if (mounted && updated == true) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Plans and billing')),
    body: FutureBuilder(
      future: billing,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return Center(child: TextButton(
            onPressed: refresh, child: const Text('Could not load billing. Retry'),
          ));
        }
        final (plan, revenue) = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.subscriptions_outlined),
                title: Text(plan['name'] as String),
                subtitle: Text(
                  '${Money.format(plan['price_paise'] as int)} / '
                  '${plan['billing_months']} month(s) · '
                  '${plan['active'] == true ? 'Active' : 'Inactive'}',
                ),
                trailing: IconButton(
                  tooltip: 'Edit plan and discount',
                  onPressed: () => edit(plan),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Test payments'),
                subtitle: Text('${revenue['successful_payments']} successful simulated payments'),
                trailing: Text(Money.format(revenue['collected_paise'] as int)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _EditPlan extends StatefulWidget {
  const _EditPlan({required this.repository, required this.plan});

  final SubscriberRepository repository;
  final Map<String, dynamic> plan;

  @override
  State<_EditPlan> createState() => _EditPlanState();
}

class _EditPlanState extends State<_EditPlan> {
  late final price = TextEditingController(
    text: ((widget.plan['price_paise'] as int) / 100).toStringAsFixed(2),
  );
  late final value = TextEditingController(
    text: widget.plan['discount_value']?.toString() ?? '',
  );
  late final start = TextEditingController(text: widget.plan['discount_start'] as String? ?? '');
  late final end = TextEditingController(text: widget.plan['discount_end'] as String? ?? '');
  late var active = widget.plan['active'] as bool;
  late var discount = widget.plan['discount_kind'] as String? ?? '';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [price, value, start, end]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() { saving = true; error = null; });
    try {
      final paise = Money.parse(price.text, allowZero: true);
      final offer = discount.isNotEmpty;
      final discountValue = offer ? int.parse(value.text.trim()) : null;
      final begins = offer ? DateTime.parse(start.text.trim()) : null;
      final ends = offer ? DateTime.parse(end.text.trim()) : null;
      if (offer && (!begins!.isUtc || !ends!.isUtc)) {
        throw const FormatException('Use a UTC timestamp');
      }
      await widget.repository.updateBillingPlan({
        'price_paise': paise,
        'active': active,
        'discount_kind': offer ? discount : null,
        'discount_value': discountValue,
        'discount_start': begins?.toIso8601String(),
        'discount_end': ends?.toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save. Check the price, discount, and UTC dates.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit monthly plan'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          enabled: !saving,
          controller: price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monthly price (₹)'),
        ),
        SwitchListTile(
          title: const Text('Plan available'),
          value: active,
          onChanged: saving ? null : (value) => setState(() => active = value),
        ),
        DropdownButtonFormField<String>(
          initialValue: discount,
          decoration: const InputDecoration(labelText: 'Discount'),
          items: const [
            DropdownMenuItem(value: '', child: Text('No discount')),
            DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
            DropdownMenuItem(value: 'fixed_paise', child: Text('Fixed amount')),
          ],
          onChanged: saving ? null : (value) => setState(() => discount = value!),
        ),
        if (discount.isNotEmpty) ...[
          TextField(
            enabled: !saving,
            controller: value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: discount == 'percentage' ? 'Percent' : 'Discount in paise',
            ),
          ),
          TextField(
            enabled: !saving,
            controller: start,
            decoration: const InputDecoration(labelText: 'Starts (UTC)', hintText: '2026-12-01T00:00Z'),
          ),
          TextField(
            enabled: !saving,
            controller: end,
            decoration: const InputDecoration(labelText: 'Ends (UTC)', hintText: '2027-01-01T00:00Z'),
          ),
        ],
        if (error != null) Text(error!),
      ]),
    ),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: const Text('Save')),
    ],
  );
}
