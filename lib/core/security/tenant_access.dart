/// Domain-level tenant authorization rules. These rules must also be enforced
/// server-side before any SaaS database query or mutation.
enum AccountRole { superAdmin, accountAdmin }

class TenantPrincipal {
  const TenantPrincipal({
    required this.userId,
    required this.role,
    this.tenantId,
  });

  final String userId;
  final AccountRole role;
  final String? tenantId;
}

class TenantAccess {
  const TenantAccess._();

  /// Subscribers may access only their own tenant.
  /// Super admins must use separately audited support workflows, never
  /// silently bypass tenant restrictions for financial records.
  static bool canAccessTenant(TenantPrincipal principal, String tenantId) {
    if (tenantId.trim().isEmpty || principal.userId.trim().isEmpty) {
      return false;
    }
    return principal.role == AccountRole.accountAdmin &&
        principal.tenantId != null &&
        principal.tenantId == tenantId;
  }

  static bool canManagePlatform(TenantPrincipal principal) =>
      principal.role == AccountRole.superAdmin &&
      principal.tenantId == null &&
      principal.userId.trim().isNotEmpty;

  static void requireTenant(TenantPrincipal principal, String tenantId) {
    if (!canAccessTenant(principal, tenantId)) {
      throw StateError('Tenant access denied');
    }
  }

  static void requirePlatformAdmin(TenantPrincipal principal) {
    if (!canManagePlatform(principal)) {
      throw StateError('Platform administrator access denied');
    }
  }
}
