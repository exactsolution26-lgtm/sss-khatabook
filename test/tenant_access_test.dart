import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/security/tenant_access.dart';

void main() {
  const alice = TenantPrincipal(
    userId: 'alice', role: AccountRole.accountAdmin, tenantId: 'tenant-a');
  const platform = TenantPrincipal(
    userId: 'platform', role: AccountRole.superAdmin);

  test('subscriber can only access own tenant', () {
    expect(TenantAccess.canAccessTenant(alice, 'tenant-a'), isTrue);
    expect(TenantAccess.canAccessTenant(alice, 'tenant-b'), isFalse);
    expect(TenantAccess.canManagePlatform(alice), isFalse);
  });

  test('platform admin manages platform but cannot silently read ledgers', () {
    expect(TenantAccess.canManagePlatform(platform), isTrue);
    expect(TenantAccess.canAccessTenant(platform, 'tenant-a'), isFalse);
  });

  test('missing identifiers and unauthorized access are denied', () {
    expect(TenantAccess.canAccessTenant(alice, ''), isFalse);
    expect(() => TenantAccess.requireTenant(alice, 'tenant-b'), throwsStateError);
    expect(() => TenantAccess.requirePlatformAdmin(alice), throwsStateError);
  });
}
