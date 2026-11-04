import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/whatsapp/whatsapp_share_service.dart';

void main() {
  test('international contact numbers can open an encoded draft link without any sending', () {
    expect(WhatsAppShareService.buildLink('+44 20 7946 0000', 'Payment reminder').path, '/442079460000');
  });
  final date = DateTime.utc(2026, 11, 4, 18, 30);
  WhatsAppDraft draft(WhatsAppMessageType type, {String details = 'Details'}) =>
      WhatsAppDraft(
        type: type,
        customer: 'Test Customer',
        amount: 2500,
        timestampUtc: date,
        details: details,
        month: 'November 2026',
      );

  test('Indian phone normalization and invalid phone', () {
    expect(
      WhatsAppShareService.normalizeIndianPhone('98765 43210'),
      '919876543210',
    );
    expect(
      WhatsAppShareService.normalizeIndianPhone('+91 9876543210'),
      '919876543210',
    );
    expect(
      () => WhatsAppShareService.normalizeIndianPhone('123'),
      throwsFormatException,
    );
    expect(
      () => WhatsAppShareService.normalizeIndianPhone('abc9876543210'),
      throwsFormatException,
    );
  });
  test('WhatsApp draft URL encodes message', () {
    final link = WhatsAppShareService.buildLink('9876543210', 'Hello & thanks');
    expect(link.host, 'wa.me');
    expect(link.queryParameters['text'], 'Hello & thanks');
  });
  test('all six message templates are available', () {
    for (final type in WhatsAppMessageType.values) {
      expect(draft(type).message, isNotEmpty);
    }
  });
  test('IST timestamp is UTC plus 05:30 including date rollover', () {
    expect(WhatsAppDraft.formatIst(date), '05/11/2026 00:00:00');
    expect(draft(WhatsAppMessageType.receipt).message, contains('IST'));
  });
  test('custom message preserves provided text', () {
    expect(
      draft(WhatsAppMessageType.custom, details: 'Custom text').message,
      'Custom text',
    );
  });
}
