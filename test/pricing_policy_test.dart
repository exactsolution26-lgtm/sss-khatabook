import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/security/tenant_access.dart';
import 'package:offline_khata_app/core/subscription/pricing_policy.dart';

void main() {
  final start = DateTime.utc(2026, 11, 1);
  final end = DateTime.utc(2026, 11, 30);
  const admin = TenantPrincipal(userId: 'owner', role: AccountRole.superAdmin);
  const subscriber = TenantPrincipal(
    userId: 'customer', role: AccountRole.accountAdmin, tenantId: 'tenant-a');

  EditablePlan plan(PlanOffer? offer) => EditablePlan(
    id: 'monthly', name: 'Monthly', pricePaise: 9900,
    billingMonths: 1, offer: offer);

  test('super admin may edit pricing; subscriber may not', () {
    expect(PricingPolicy.updatePlan(actor: admin, replacement: plan(null))
        .pricePaise, 9900);
    expect(() => PricingPolicy.updatePlan(
        actor: subscriber, replacement: plan(null)), throwsStateError);
  });

  test('percentage discount shown as original, savings and payable', () {
    final quote = PricingPolicy.quote(
      plan(PlanOffer(kind: DiscountKind.percentage, value: 20,
          startsAtUtc: start, endsAtUtc: end)),
      DateTime.utc(2026, 11, 3),
    );
    expect(quote.originalPaise, 9900);
    expect(quote.discountPaise, 1980);
    expect(quote.payablePaise, 7920);
  });

  test('fixed discount and expiry boundary', () {
    final discounted = plan(PlanOffer(kind: DiscountKind.fixedPaise,
        value: 1500, startsAtUtc: start, endsAtUtc: end));
    expect(PricingPolicy.quote(discounted, start).payablePaise, 8400);
    expect(PricingPolicy.quote(discounted, end).payablePaise, 9900);
  });

  test('rejects over-discounting and inactive plans', () {
    expect(() => PricingPolicy.quote(plan(PlanOffer(
      kind: DiscountKind.percentage, value: 101,
      startsAtUtc: start, endsAtUtc: end)), start), throwsArgumentError);
    expect(() => PricingPolicy.quote(
      const EditablePlan(id: 'off', name: 'Disabled',
          pricePaise: 9900, billingMonths: 1, active: false), start),
      throwsStateError);
  });
}
