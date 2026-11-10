import 'money.dart';

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
    try {
      return Money.parse(input) / 100;
    } on ArgumentError {
      throw const FormatException('Enter a positive amount with at most two decimals');
    }
  }

  static bool isValidAmount(String input) {
    try {
      parseAmount(input);
      return true;
    } on FormatException {
      return false;
    }
  }
}
