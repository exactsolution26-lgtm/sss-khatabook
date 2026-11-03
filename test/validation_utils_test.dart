import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/utils/validation_utils.dart';

void main() {
  test(
    'forms reject non-finite money and values outside SQLite guard limits',
    () {
      for (final value in ['NaN', 'Infinity', '-Infinity', '90000000000001']) {
        expect(ValidationUtils.validateAmount(value), isNotNull);
        expect(ValidationUtils.validateBalance(value), isNotNull);
      }
      expect(ValidationUtils.validateAmount('0.01'), isNull);
      expect(ValidationUtils.validateBalance('0'), isNull);
    },
  );
}
