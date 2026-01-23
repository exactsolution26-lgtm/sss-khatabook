class WorkTable {
  static const String tableName = 'work';

  static const String id = 'id';
  static const String date = 'date';
  static const String startTime = 'start_time';
  static const String endTime = 'end_time';
  static const String duration = 'duration';
  static const String description = 'description';
  static const String createdAt = 'created_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $id INTEGER PRIMARY KEY AUTOINCREMENT,
      $date TEXT NOT NULL,
      $startTime TEXT,
      $endTime TEXT,
      $duration INTEGER NOT NULL DEFAULT 0,
      $description TEXT,
      $createdAt TEXT NOT NULL
    )
  ''';
}
