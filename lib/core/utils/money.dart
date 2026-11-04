class Money {
  // Bridge to legacy REAL cash rows without losing a paise per payment.
  static const maximumPaise = 9000000000000;
  static int parse(String input, {bool allowZero = false}) {
    final value = input.trim();
    if (!RegExp(r'^\d{1,14}(?:\.\d{1,2})?$').hasMatch(value)) throw ArgumentError('Use an amount with at most two decimals');
    final parts = value.split('.');
    final paise = int.parse(parts[0]) * 100 + int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (paise > maximumPaise || paise < (allowZero ? 0 : 1)) throw ArgumentError('Amount out of range');
    return paise;
  }
  static String format(int paise) {
    final value = paise.abs();
    var rupees = (value ~/ 100).toString();
    if (rupees.length > 3) {
      final tail = rupees.substring(rupees.length - 3);
      var prefix = rupees.substring(0, rupees.length - 3);
      final groups = <String>[];
      while (prefix.length > 2) {groups.insert(0, prefix.substring(prefix.length - 2)); prefix = prefix.substring(0, prefix.length - 2);}
      groups.insert(0, prefix); rupees = '${groups.join(',')},$tail';
    }
    return '${paise < 0 ? '-₹' : '₹'}$rupees.${(value % 100).toString().padLeft(2, '0')}';
  }
}
