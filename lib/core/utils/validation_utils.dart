class ValidationUtils {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter amount';
    }
    try {
      final amount = double.parse(value);
      if (amount <= 0) {
        return 'Amount must be greater than 0';
      }
      return null;
    } catch (e) {
      return 'Please enter a valid amount';
    }
  }

  static String? validateBalance(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter balance';
    }
    try {
      final balance = double.parse(value);
      if (balance < 0) {
        return 'Balance cannot be negative';
      }
      return null;
    } catch (e) {
      return 'Please enter a valid balance';
    }
  }

  static String? validateAccountName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter account name';
    }
    if (value.trim().length < 2) {
      return 'Account name must be at least 2 characters';
    }
    return null;
  }
}
