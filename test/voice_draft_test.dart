import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/voice/voice_draft.dart';
void main() {
  test('English/Hindi speech drafts extract only one explicit numeric amount',() {
    final english=VoiceDraft.parse('Received 500 rupees from Ravi');expect(english.amount,'500');expect(english.income,true);
    final hindi=VoiceDraft.parse('५०० रुपये खर्च किए');expect(hindi.amount,'500');expect(hindi.income,false);
    expect(VoiceDraft.parse('Paid 25.50 cash').amount,'25.50');
  });
  test('ambiguous amounts/types and unrecognized number words require manual review',() {
    expect(VoiceDraft.parse('Received 500 on 4 November').amount,isNull);
    expect(VoiceDraft.parse('Paid five hundred').amount,isNull);
    expect(VoiceDraft.parse('Received 500 and paid').income,isNull);
    expect(VoiceDraft.parse('Paid 1.005').amount,isNull);
    expect(() => VoiceDraft.parse(''),throwsFormatException);
  });
}
