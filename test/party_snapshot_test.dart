import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/entries/party_snapshot.dart';

void main() {
  test('ledger allows a trimmed name without a phone', () {
    final party = PartySnapshot.optional('  shambhu  ', '  ', allowNameOnly: true)!;
    expect(party.toMap(), {'contact_name': 'shambhu', 'contact_phone': ''});
    expect(PartySnapshot.optional('', '', allowNameOnly: true), isNull);
  });

  test('provided phones remain validated and normalized', () {
    expect(PartySnapshot.optional('Ravi', '98765 43210', allowNameOnly: true)!.phone, '+919876543210');
    for (final phone in ['invalid', '123', '+00000000']) {
      expect(() => PartySnapshot.optional('Ravi', phone, allowNameOnly: true), throwsArgumentError);
    }
    expect(() => PartySnapshot.optional('', '9876543210', allowNameOnly: true), throwsArgumentError);
    expect(() => PartySnapshot.optional('x' * 121, '', allowNameOnly: true), throwsArgumentError);
  });

  test('directory and WhatsApp callers still require a phone by default', () {
    expect(() => PartySnapshot.optional('Ravi', ''), throwsArgumentError);
  });
}
