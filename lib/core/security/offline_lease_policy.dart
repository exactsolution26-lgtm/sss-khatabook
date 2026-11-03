/// Pure offline authorization policy. Cryptographic signature verification,
/// trusted server timestamps and secure persisted state must be supplied by
/// the production licensing layer before this is used to authorize access.
class OfflineLease {
  const OfflineLease({
    required this.tenantId,
    required this.deviceId,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
  });

  final String tenantId;
  final String deviceId;
  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;
}

enum OfflineLeaseStatus {
  valid,
  expired,
  notYetValid,
  invalid,
  deviceMismatch,
  tenantMismatch,
  clockRollback,
}

class OfflineLeasePolicy {
  const OfflineLeasePolicy._();

  static const maximumDuration = Duration(days: 30);
  static const clockTolerance = Duration(minutes: 5);

  static OfflineLeaseStatus evaluate({
    required OfflineLease lease,
    required String tenantId,
    required String deviceId,
    required DateTime nowUtc,
    required DateTime lastTrustedUtc,
  }) {
    if (tenantId.isEmpty || lease.tenantId.isEmpty ||
        deviceId.isEmpty || lease.deviceId.isEmpty ||
        !lease.issuedAtUtc.isUtc || !lease.expiresAtUtc.isUtc ||
        !nowUtc.isUtc || !lastTrustedUtc.isUtc ||
        !lease.expiresAtUtc.isAfter(lease.issuedAtUtc) ||
        lease.expiresAtUtc.difference(lease.issuedAtUtc) > maximumDuration) {
      return OfflineLeaseStatus.invalid;
    }
    if (lease.tenantId != tenantId) {
      return OfflineLeaseStatus.tenantMismatch;
    }
    if (lease.deviceId != deviceId) {
      return OfflineLeaseStatus.deviceMismatch;
    }
    if (nowUtc.add(clockTolerance).isBefore(lastTrustedUtc)) {
      return OfflineLeaseStatus.clockRollback;
    }
    if (nowUtc.isBefore(lease.issuedAtUtc)) {
      return OfflineLeaseStatus.notYetValid;
    }
    if (!nowUtc.isBefore(lease.expiresAtUtc)) {
      return OfflineLeaseStatus.expired;
    }
    return OfflineLeaseStatus.valid;
  }
}
