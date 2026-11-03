/// Display/catalogue configuration only. Server must independently verify
/// prices, taxes, payments, subscription entitlements and renewals.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.pricePaise,
    required this.billingMonths,
    required this.currency,
  });

  final String id;
  final int pricePaise;
  final int billingMonths;
  final String currency;
}

class SubscriptionCatalog {
  const SubscriptionCatalog._();

  static const monthly = SubscriptionPlan(
    id: 'monthly_99_inr',
    pricePaise: 9900,
    billingMonths: 1,
    currency: 'INR',
  );
}
