import 'package:sqflite/sqflite.dart';

class WorkspaceSchema {
  static const tables = ['business_profile','contact_directory','message_templates','import_records'];
  static Future<void> install(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS business_profile (
      id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
      phone TEXT NOT NULL, email TEXT NOT NULL, address TEXT NOT NULL CHECK(length(address)<=500),
      updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS contact_directory (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
      phone TEXT NOT NULL UNIQUE CHECK(length(phone) BETWEEN 8 AND 16), updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS message_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(title)) BETWEEN 1 AND 80),
      body TEXT NOT NULL CHECK(length(trim(body)) BETWEEN 1 AND 4000), updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS import_records (
      source_key TEXT PRIMARY KEY, content_hash TEXT NOT NULL CHECK(length(content_hash)=64),
      kind TEXT NOT NULL CHECK(kind IN ('income','expense')), record_id INTEGER NOT NULL CHECK(record_id>0), created_at TEXT NOT NULL)''');
  }
}
