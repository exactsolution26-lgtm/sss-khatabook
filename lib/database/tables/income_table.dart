class IncomeTable {
  static const String tableName = 'income';

  static const String id = 'id';
  static const String accountId = 'account_id';
  static const String amount = 'amount';
  static const String description = 'description';
  static const String date = 'date';
  static const String createdAt = 'created_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $id INTEGER PRIMARY KEY AUTOINCREMENT,
      $accountId INTEGER NOT NULL,
      $amount REAL NOT NULL,
      $description TEXT,
      $date TEXT NOT NULL,
      $createdAt TEXT NOT NULL,
      FOREIGN KEY ($accountId) REFERENCES accounts($id)
    )
  ''';
}
