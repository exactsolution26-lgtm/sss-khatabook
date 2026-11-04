import 'money.dart';
class ValidationUtils {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    try {Money.parse(value ?? '');return null;} catch(_) {return 'Enter a positive amount with at most two decimals';}
  }
  static String? validateBalance(String? value) {
    try {Money.parse(value ?? '',allowZero: true);return null;} catch(_) {return 'Enter a balance with at most two decimals';}
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
