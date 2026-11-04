import '../../core/utils/money.dart';

/// Deliberately conservative: ambiguous speech remains for manual review.
class VoiceDraft {
  VoiceDraft(this.transcript,{this.amount,this.income});
  final String transcript;
  final String? amount;
  final bool? income;
  static VoiceDraft parse(String input) {
    var text=input.trim();
    if(text.isEmpty || text.length>2000) throw const FormatException('Enter a short phrase');
    for(var i=0;i<10;i++) {text=text.replaceAll('०१२३४५६७८९'[i],'$i');}
    final matches=RegExp(r'(?<![\d.])\d+(?:\.\d{1,2})?(?![\d.])').allMatches(text).toList();
    String? amount;
    if(matches.length==1) {
      final candidate=matches.single.group(0)!;
      try {Money.parse(candidate);amount=candidate;} catch (_) { /* Keep amount blank for explicit review. */ }
    }
    final incoming=RegExp(r'\b(income|received|earned|salary)\b|आय|प्राप्त|मिले',caseSensitive: false).hasMatch(text);
    final expense=RegExp(r'\b(expense|paid|spent)\b|खर्च|भुगतान|दिए',caseSensitive: false).hasMatch(text);
    return VoiceDraft(input.trim(),amount: amount,income: incoming==expense ? null : incoming);
  }
}
