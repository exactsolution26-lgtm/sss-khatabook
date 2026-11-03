class CalculationUtils {
  static double add(double a, double b) => a + b;
  static double subtract(double a, double b) => a - b;
  static double multiply(double a, double b) => a * b;
  static double divide(double a, double b) {
    if (b == 0) throw ArgumentError('Cannot divide by zero');
    return a / b;
  }

  static String formatCurrency(double amount) =>
      '₹${amount.toStringAsFixed(2)}';

  static double parseAmount(String input) {
    final amount = double.tryParse(input.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw FormatException('Enter a valid positive amount');
    }
    return amount;
  }

  static bool isValidAmount(String input) {
    final amount = double.tryParse(input.trim());
    return amount != null && amount.isFinite && amount > 0;
  }
}
