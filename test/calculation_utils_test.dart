import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/utils/calculation_utils.dart';

void main() {
  test('valid amounts parse', () {
    expect(CalculationUtils.parseAmount(' 12.50 '), 12.5);
    expect(CalculationUtils.isValidAmount('0.01'), isTrue);
  });

  test('invalid and non-finite amounts rejected', () {
    for (final value in ['', 'abc', '0', '-1', 'NaN', 'Infinity']) {
      expect(CalculationUtils.isValidAmount(value), isFalse);
      expect(() => CalculationUtils.parseAmount(value), throwsFormatException);
    }
  });

  test('division by zero is explicit', () {
    expect(() => CalculationUtils.divide(10, 0), throwsArgumentError);
  });
}
