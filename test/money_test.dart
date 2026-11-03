import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/utils/money.dart';

void main() {
  group('Exact INR arithmetic', () {
    test('0.10 + 0.20 is exactly 0.30', () {
      expect((Money.parseRupees('0.10') + Money.parseRupees('0.20')).toRupees(), '0.30');
    });
    test('large carry across rupees', () {
      expect((Money.parseRupees('999999.99') + Money.parseRupees('0.01')).toRupees(), '1000000.00');
    });
    test('opening plus income minus expense', () {
      final balance = Money.parseRupees('1000') + Money.parseRupees('500') - Money.parseRupees('200');
      expect(balance.toRupees(), '1300.00');
    });
    test('transfer does not change combined balance', () {
      final cash = Money.parseRupees('1000') - Money.parseRupees('300');
      final bank = Money.parseRupees('0') + Money.parseRupees('300');
      expect((cash + bank).toRupees(), '1000.00');
    });
    test('expense edit adjusts only the difference', () {
      expect((Money.parseRupees('250') - Money.parseRupees('200')).toRupees(), '50.00');
    });
    test('rejects invalid and excess precision', () {
      for (final invalid in ['abc', '-1', '1.234', 'NaN', '', '1e4']) {
        expect(() => Money.parseRupees(invalid), throwsFormatException);
      }
    });
    test('preserves two decimal places', () {
      expect(Money.parseRupees('12.5').toRupees(), '12.50');
      expect(Money.parseRupees('0').toRupees(), '0.00');
    });
  });
}
