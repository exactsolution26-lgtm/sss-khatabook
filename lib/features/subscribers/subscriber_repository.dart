import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscriber_account.dart';

/// All operations use the authenticated session and database RLS.
class SubscriberRepository {
  SubscriberRepository(this.client);
  final SupabaseClient client;

  Future<void> requireSuperAdmin() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in required');
    final result = await client.rpc('is_platform_admin');
    if (result != true) throw StateError('Super Admin access required');
  }

  Future<List<SubscriberAccount>> list() async {
    await requireSuperAdmin();
    final rows = await client.from('subscriber_accounts')
        .select('id,owner_user_id,display_name,status')
        .order('created_at', ascending: false);
    return rows.map((row) => SubscriberAccount.fromJson(row)).toList();
  }

  Future<void> create({
    required String ownerUserId,
    required String displayName,
  }) async {
    await requireSuperAdmin();
    final name = displayName.trim();
    if (name.isEmpty || name.length > 120) throw ArgumentError('Invalid name');
    await client.from('subscriber_accounts').insert({
      'owner_user_id': ownerUserId,
      'display_name': name,
    });
  }

  Future<void> update({
    required String accountId,
    required String displayName,
    required bool active,
  }) async {
    await requireSuperAdmin();
    final name = displayName.trim();
    if (name.isEmpty || name.length > 120) throw ArgumentError('Invalid name');
    await client.from('subscriber_accounts').update({
      'display_name': name,
      'status': active ? 'active' : 'suspended',
    }).eq('id', accountId);
  }
}
