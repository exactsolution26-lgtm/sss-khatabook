import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'offline_lease_policy.dart';

class LeaseVerificationException implements Exception {
  const LeaseVerificationException(this.status);
  final OfflineLeaseStatus status;
  @override
  String toString() => 'Offline authorization unavailable (${status.name})';
}
class VerifiedOfflineLease {
  const VerifiedOfflineLease(this.lease, this.leaseId, this.subscriptionId);
  final OfflineLease lease;
  final String leaseId, subscriptionId;
}

/// Production keys must be provisioned by the platform owner. No bundled test
/// key, unsigned fallback, private signing key or local entitlement mint exists.
class SignedOfflineLeaseVerifier {
  SignedOfflineLeaseVerifier(Map<String, List<int>> keys) : keys = Map.unmodifiable({
    for (final entry in keys.entries) entry.key: List<int>.unmodifiable(entry.value),
  });
  final Map<String, List<int>> keys;
  static List<int> signingBytes(String encodedPayload) => [
    ...utf8.encode('SSS-KHATABOOK-LICENSE-V1\n'), ...base64Url.decode(base64Url.normalize(encodedPayload)),
  ];
  Future<VerifiedOfflineLease> verify(String envelope, {required String tenantId,
      required String deviceId, required DateTime nowUtc, required DateTime lastTrustedUtc}) async {
    try {
      if (envelope.length > 10000) throw const FormatException('License too large');
      final object = jsonDecode(envelope) as Map<String, dynamic>;
      if (object.length != 2 || !object.containsKey('payload') || !object.containsKey('signature')) {
        throw const FormatException('Invalid signed envelope');
      }
      final payload = object['payload'] as String;
      final bytes = base64Url.decode(base64Url.normalize(payload));
      if (bytes.length > 4096) throw const FormatException('License payload too large');
      final claims = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      const fields = ['v','kid','lease_id','subscription_id','tenant_id','device_id','issued_at','expires_at'];
      if (claims.length != fields.length || !fields.every(claims.containsKey) || claims['v'] != 1) {
        throw const FormatException('Unsupported license');
      }
      for (final field in fields.skip(1)) {
        if (claims[field] is! String || (claims[field] as String).isEmpty || (claims[field] as String).length > 256) {
          throw const FormatException('Invalid license claim');
        }
      }
      final key = keys[claims['kid']];
      final signature = base64Url.decode(base64Url.normalize(object['signature'] as String));
      if (key == null || key.length != 32 || signature.length != 64 ||
          !await Ed25519().verify(signingBytes(payload), signature: Signature(signature,
            publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)))) {
        throw const FormatException('Invalid signature');
      }
      final lease = OfflineLease(tenantId: claims['tenant_id'] as String, deviceId: claims['device_id'] as String,
        issuedAtUtc: DateTime.parse(claims['issued_at'] as String), expiresAtUtc: DateTime.parse(claims['expires_at'] as String));
      final status = OfflineLeasePolicy.evaluate(lease: lease, tenantId: tenantId, deviceId: deviceId,
        nowUtc: nowUtc, lastTrustedUtc: lastTrustedUtc);
      if (status != OfflineLeaseStatus.valid) throw LeaseVerificationException(status);
      return VerifiedOfflineLease(lease, claims['lease_id'] as String, claims['subscription_id'] as String);
    } on LeaseVerificationException { rethrow; }
    catch (_) {throw const LeaseVerificationException(OfflineLeaseStatus.invalid);}
  }
}
