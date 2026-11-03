import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/localization/app_strings.dart';

void main() {
  test('English is available for core subscription labels', () {
    expect(LocalizedStrings.get('monthlyPlan', AppLanguage.english), 'Monthly Plan');
    expect(LocalizedStrings.get('discount', AppLanguage.english), 'Discount');
  });

  test('Hindi translations are optional and selectable', () {
    expect(LocalizedStrings.get('monthlyPlan', AppLanguage.hindi), 'मासिक प्लान');
  });

  test('unknown keys fail visibly instead of silently hiding text', () {
    expect(() => LocalizedStrings.get('missing', AppLanguage.english),
        throwsArgumentError);
  });
}
