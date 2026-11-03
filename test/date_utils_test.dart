import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/utils/date_utils.dart';
import 'package:offline_khata_app/models/account_model.dart';

void main() {
  test('UTC timestamps survive serialization and preserve the instant', () {
    final utc = DateTime.utc(2026, 11, 4, 1, 2, 3);
    expect(DateUtils.parseDateTime(DateUtils.formatDateTime(utc)), utc);
    expect(DateUtils.parseDateTime('2026-11-04T06:32:03+05:30').toUtc(), utc);
  });
  test('legacy space-separated timestamps still load', () {
    final legacy = DateUtils.parseDateTime('2026-10-01 13:20:30');
    expect(legacy.year, 2026);
    expect(legacy.hour, 13);
  });
  test('account rows created using ISO UTC load without a parse error', () {
    final account = AccountModel.fromMap({
      'id': 7,
      'name': 'Saved Account',
      'opening_balance': 100,
      'created_at': '2026-11-04T01:02:03.000Z',
    });
    expect(account.createdAt, DateTime.utc(2026, 11, 4, 1, 2, 3));
    expect(() => DateUtils.parseDateTime('not a date'), throwsFormatException);
  });
}
