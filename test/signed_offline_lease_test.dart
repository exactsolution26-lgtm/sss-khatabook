import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/security/signed_offline_lease.dart';
import 'package:offline_khata_app/core/security/offline_lease_policy.dart';

void main() {
  test('real Ed25519 license verifies and rejects changed claims, forged signature and unknown keys', () async {
    final signing = await Ed25519().newKeyPair();
    final public = await signing.extractPublicKey();
    final verifier = SignedOfflineLeaseVerifier({'production-key-id': public.bytes});
    final issued = DateTime.utc(2026, 11, 4);
    final claims = {'v': 1, 'kid': 'production-key-id', 'lease_id': 'lease-test',
      'subscription_id': 'subscription-test', 'tenant_id': 'tenant-A', 'device_id': 'device-A',
      'issued_at': issued.toIso8601String(), 'expires_at': issued.add(const Duration(days: 30)).toIso8601String()};
    final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
    final signature = await Ed25519().sign(SignedOfflineLeaseVerifier.signingBytes(payload), keyPair: signing);
    final envelope = jsonEncode({'payload': payload, 'signature': base64Url.encode(signature.bytes)});
    Future<VerifiedOfflineLease> verify(String text, {String tenant = 'tenant-A', String device = 'device-A', DateTime? now}) =>
      verifier.verify(text, tenantId: tenant, deviceId: device, nowUtc: now ?? issued.add(const Duration(days: 29)), lastTrustedUtc: issued);
    expect((await verify(envelope)).subscriptionId, 'subscription-test');
    await expectLater(verify(envelope, tenant: 'tenant-B'), throwsA(isA<LeaseVerificationException>()));
    await expectLater(verify(envelope, device: 'device-B'), throwsA(isA<LeaseVerificationException>()));
    await expectLater(verify(envelope, now: issued.add(const Duration(days: 30))),
      throwsA(isA<LeaseVerificationException>().having((e) => e.status, 'status', OfflineLeaseStatus.expired)));
    final modified = {...claims, 'tenant_id': 'tenant-B'};
    await expectLater(verify(jsonEncode({'payload': base64Url.encode(utf8.encode(jsonEncode(modified))),
      'signature': base64Url.encode(signature.bytes)})), throwsA(isA<LeaseVerificationException>()));
    await expectLater(verify(jsonEncode({'payload': payload, 'signature': base64Url.encode(List.filled(64, 0))})),
      throwsA(isA<LeaseVerificationException>()));
    await expectLater(SignedOfflineLeaseVerifier({}).verify(envelope, tenantId: 'tenant-A', deviceId: 'device-A',
      nowUtc: issued, lastTrustedUtc: issued), throwsA(isA<LeaseVerificationException>()));
    await expectLater(verifier.verify(envelope, tenantId: 'tenant-A', deviceId: 'device-A',
      nowUtc: issued, lastTrustedUtc: issued.add(const Duration(days: 1))),
      throwsA(isA<LeaseVerificationException>().having((e) => e.status, 'status', OfflineLeaseStatus.clockRollback)));
  });
}
