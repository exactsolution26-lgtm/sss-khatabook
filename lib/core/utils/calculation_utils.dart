class CalculationUtils {
  static double add(double a, double b) => a + b;

  static double subtract(double a, double b) => a - b;

  static double multiply(double a, double b) => a * b;

  static double divide(double a, double b) {
    if (b == 0) return 0;
    return a / b;
  }

  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  static double parseAmount(String amountString) {
    try {
      return double.parse(amountString);
    } catch (e) {
      return 0.0;
    }
  }

  static bool isValidAmount(String amount) {
    try {
      final value = double.parse(amount);
      return value > 0;
    } catch (e) {
      return false;
    }
  }
}
