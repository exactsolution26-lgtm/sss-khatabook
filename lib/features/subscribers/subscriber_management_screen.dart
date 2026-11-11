import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'billing_admin_screen.dart';
import 'subscriber_account.dart';
import 'subscriber_repository.dart';

class SubscriberManagementScreen extends StatefulWidget {
  const SubscriberManagementScreen({super.key});

  @override
  State<SubscriberManagementScreen> createState() =>
      _SubscriberManagementScreenState();
}

class _SubscriberManagementScreenState
    extends State<SubscriberManagementScreen> {
  late final SubscriberRepository repository = SubscriberRepository(
    Supabase.instance.client,
  );
  late Future<List<SubscriberAccount>> accounts = repository.list();

  void refresh() {
    if (mounted) setState(() {accounts = repository.list();});
  }

  Future<void> edit([SubscriberAccount? account]) async {
    final name = TextEditingController(text: account?.displayName ?? '');
    final owner = TextEditingController(text: account?.ownerUserId ?? '');
    var active = account?.isActive ?? true;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(account == null ? 'Add Subscriber' : 'Edit Subscriber'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (account == null)
                TextField(
                  controller: owner,
                  decoration: const InputDecoration(
                    labelText: 'Existing Auth User UUID',
                  ),
                ),
              TextField(
                controller: name,
                decoration: const InputDecoration(label: AppText('Account Name')),
              ),
              if (account != null)
                SwitchListTile(
                  title: const AppText('Active'),
                  value: active,
                  onChanged: (value) => update(() => active = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      name.dispose();
      owner.dispose();
      return;
    }
    if (submitted == true) {
      try {
        if (account == null) {
          await repository.create(
            ownerUserId: owner.text,
            displayName: name.text,
          );
        } else {
          await repository.update(
            accountId: account.id,
            displayName: name.text,
            active: active,
          );
        }
        refresh();
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText('Unable to save subscriber. Check account details and your access.',
              ),
            ),
          );
      }
    }
    name.dispose();
    owner.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Subscriber Accounts'),
      actions: [
        IconButton(
          tooltip: 'Plans and billing',
          icon: const Icon(Icons.payments_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => BillingAdminScreen(repository: repository),
          )),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.person_add_alt_1),
      label: const AppText('Add Subscriber'),
    ),
    body: FutureBuilder<List<SubscriberAccount>>(
      future: accounts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppText('Unable to load subscriber accounts'),
                TextButton(onPressed: refresh, child: const AppText('Retry')),
              ],
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: AppText('No subscriber accounts yet'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final account = items[index];
            return ListTile(
              title: Text(account.displayName),
              subtitle: Text(account.isActive ? 'Active' : 'Suspended'),
              trailing: IconButton(
                tooltip: 'Edit Subscriber',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => edit(account),
              ),
            );
          },
        );
      },
    ),
  );
}
