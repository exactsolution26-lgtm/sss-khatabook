/// Exact INR money representation in integer paise.
/// This helper is intended for new ledger code; legacy REAL data still
/// requires a reviewed and tested migration before conversion.
class Money {
  const Money._(this.paise);

  final int paise;

  static Money parseRupees(String input) {
    final value = input.trim();
    if (!RegExp(r'^\\d+(?:\\.\\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('Enter a valid INR amount (up to 2 decimals).');
    }
    final parts = value.split('.');
    final rupees = int.parse(parts[0]);
    final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
    // Bound arithmetic to signed 64-bit for consistent storage.
    const maxPaise = 9223372036854775807;
    if (rupees > (maxPaise - fraction) ~/ 100) {
      throw const FormatException('Amount is too large.');
    }
    return Money._(rupees * 100 + fraction);
  }

  Money operator +(Money other) => Money._(_checked(paise, other.paise, true));
  Money operator -(Money other) => Money._(_checked(paise, other.paise, false));

  static int _checked(int a, int b, bool add) {
    final result = add ? a + b : a - b;
    const max = 9223372036854775807;
    const min = -9223372036854775808;
    if (result > max || result < min) {
      throw RangeError('Money calculation overflow');
    }
    return result;
  }

  String toRupees() {
    final absolute = paise.abs();
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${paise < 0 ? '-' : ''}$whole.$fraction';
  }
}
