/// UI translation catalogue. English is the default; Hindi is optional.
/// Add new user-facing text here rather than hardcoding it in screens.
enum AppLanguage { english, hindi }

class LocalizedStrings {
  const LocalizedStrings._();

  static const Map<String, Map<AppLanguage, String>> _values = {
    'appTitle': {AppLanguage.english: 'SSS Khatabook', AppLanguage.hindi: 'एसएसएस खाताबुक'},
    'dashboard': {AppLanguage.english: 'Dashboard', AppLanguage.hindi: 'डैशबोर्ड'},
    'accounts': {AppLanguage.english: 'Accounts', AppLanguage.hindi: 'खाते'},
    'income': {AppLanguage.english: 'Income', AppLanguage.hindi: 'आय'},
    'expenses': {AppLanguage.english: 'Expenses', AppLanguage.hindi: 'खर्च'},
    'reports': {AppLanguage.english: 'Reports', AppLanguage.hindi: 'रिपोर्ट'},
    'settings': {AppLanguage.english: 'Settings', AppLanguage.hindi: 'सेटिंग्स'},
    'subscription': {AppLanguage.english: 'Subscription', AppLanguage.hindi: 'सदस्यता'},
    'monthlyPlan': {AppLanguage.english: 'Monthly Plan', AppLanguage.hindi: 'मासिक प्लान'},
    'originalPrice': {AppLanguage.english: 'Original Price', AppLanguage.hindi: 'मूल कीमत'},
    'discount': {AppLanguage.english: 'Discount', AppLanguage.hindi: 'छूट'},
    'finalPrice': {AppLanguage.english: 'Final Price', AppLanguage.hindi: 'अंतिम कीमत'},
    'yourSavings': {AppLanguage.english: 'Your Savings', AppLanguage.hindi: 'आपकी बचत'},
    'renew': {AppLanguage.english: 'Renew', AppLanguage.hindi: 'नवीनीकरण करें'},
    'language': {AppLanguage.english: 'Language', AppLanguage.hindi: 'भाषा'},
    'english': {AppLanguage.english: 'English', AppLanguage.hindi: 'अंग्रेज़ी'},
    'hindi': {AppLanguage.english: 'Hindi', AppLanguage.hindi: 'हिंदी'},
    'superAdmin': {AppLanguage.english: 'Super Admin', AppLanguage.hindi: 'सुपर एडमिन'},
    'save': {AppLanguage.english: 'Save', AppLanguage.hindi: 'सहेजें'},
    'cancel': {AppLanguage.english: 'Cancel', AppLanguage.hindi: 'रद्द करें'},
    'error': {AppLanguage.english: 'Something went wrong', AppLanguage.hindi: 'कुछ गलत हो गया'},
  };

  static String get(String key, AppLanguage language) {
    final translations = _values[key];
    if (translations == null) {
      throw ArgumentError.value(key, 'key', 'Missing UI translation');
    }
    return translations[language] ?? translations[AppLanguage.english]!;
  }
}
