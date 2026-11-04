import 'package:flutter/material.dart';

/// A visual reconstruction only. It never loads platform data or grants roles.
class SuperAdminPreview extends StatelessWidget {
  const SuperAdminPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Super Admin Preview')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('RECONSTRUCTION · SIMULATED PLATFORM DATA'),
      const SizedBox(height: 16),
      Text('Platform overview', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      const Card(child: ListTile(leading: Icon(Icons.people_outline),
        title: Text('Subscribers'), subtitle: Text('3 sample subscribers · 2 paid'))),
      Card(color: Theme.of(context).colorScheme.primaryContainer,
        child: const ListTile(leading: Icon(Icons.payments_outlined),
          title: Text('Sample payments received'), subtitle: Text('₹198.00 · two ₹99 payments'))),
      const SizedBox(height: 20),
      for (final label in ['Subscribers', 'Plans & pricing', 'Discounts & offers',
        'Payments & renewals', 'Revenue reports', 'Dashboard templates', 'Platform settings'])
        Card(child: ListTile(title: Text(label),
          subtitle: const Text('Design preview — management not connected'),
          trailing: const Icon(Icons.lock_outline))),
    ]),
  );
}
