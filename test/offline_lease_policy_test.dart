import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/security/offline_lease_policy.dart';

void main() {
  final issued = DateTime.utc(2026, 11, 1);
  final lease = OfflineLease(
    tenantId: 'tenant-a',
    deviceId: 'phone-a',
    issuedAtUtc: issued,
    expiresAtUtc: issued.add(const Duration(days: 30)),
  );

  OfflineLeaseStatus check(DateTime now, {
    OfflineLease? candidate,
    String tenant = 'tenant-a',
    String device = 'phone-a',
    DateTime? trusted,
  }) => OfflineLeasePolicy.evaluate(
    lease: candidate ?? lease,
    tenantId: tenant,
    deviceId: device,
    nowUtc: now,
    lastTrustedUtc: trusted ?? issued,
  );

  test('valid through day 29 but not at day 30 boundary', () {
    expect(check(issued.add(const Duration(days: 29))), OfflineLeaseStatus.valid);
    expect(check(issued.add(const Duration(days: 30))), OfflineLeaseStatus.expired);
  });

  test('tenant and device binding enforced', () {
    expect(check(issued, tenant: 'tenant-b'), OfflineLeaseStatus.tenantMismatch);
    expect(check(issued, device: 'phone-b'), OfflineLeaseStatus.deviceMismatch);
  });

  test('rejects rollback and future leases', () {
    expect(check(issued.subtract(const Duration(hours: 1)), trusted: issued),
        OfflineLeaseStatus.clockRollback);
    expect(check(issued.subtract(const Duration(minutes: 1)),
        trusted: issued.subtract(const Duration(minutes: 1))),
        OfflineLeaseStatus.notYetValid);
  });

  test('rejects leases longer than thirty days', () {
    final longLease = OfflineLease(
      tenantId: 'tenant-a',
      deviceId: 'phone-a',
      issuedAtUtc: issued,
      expiresAtUtc: issued.add(const Duration(days: 31)),
    );
    expect(check(issued, candidate: longLease), OfflineLeaseStatus.invalid);
  });
}
