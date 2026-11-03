import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/subscribers/subscriber_account.dart';

void main() {
  test('subscriber model parses account and status', () {
    final account = SubscriberAccount.fromJson({
      'id': 'a', 'owner_user_id': 'u',
      'display_name': 'Business One', 'status': 'active',
    });
    expect(account.displayName, 'Business One');
    expect(account.isActive, isTrue);
  });
  test('suspended subscriber is not active', () {
    final account = SubscriberAccount.fromJson({
      'id': 'b', 'owner_user_id': 'v',
      'display_name': 'Business Two', 'status': 'suspended',
    });
    expect(account.isActive, isFalse);
  });
}
