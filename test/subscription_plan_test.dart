import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/subscription/subscription_plan.dart';

void main() {
  test('approved monthly plan is INR 99 in minor units', () {
    expect(SubscriptionCatalog.monthly.id, 'monthly_99_inr');
    expect(SubscriptionCatalog.monthly.pricePaise, 9900);
    expect(SubscriptionCatalog.monthly.billingMonths, 1);
    expect(SubscriptionCatalog.monthly.currency, 'INR');
  });
}
