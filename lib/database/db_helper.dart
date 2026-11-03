import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Fresh v2 local database. The earlier v1 file contained demo-only data.
/// This is local groundwork, not cloud SaaS authentication or tenant isolation.
class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final file = join(dbPath, 'sss_khatabook_v2.db');
    return openDatabase(
      file,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE businesses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at_utc TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            business_id TEXT NOT NULL REFERENCES businesses(id),
            name TEXT NOT NULL,
            balance_paise INTEGER NOT NULL DEFAULT 0,
            UNIQUE(business_id, name),
            UNIQUE(id, business_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            business_id TEXT NOT NULL REFERENCES businesses(id),
            account_id TEXT NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('income','expense','transfer_in','transfer_out')),
            amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
            category TEXT NOT NULL,
            party_name TEXT NOT NULL DEFAULT '',
            payment_mode TEXT NOT NULL CHECK(payment_mode IN ('cash','upi','bank')),
            note TEXT NOT NULL DEFAULT '',
            occurred_at_utc TEXT NOT NULL,
            created_at_utc TEXT NOT NULL,
            updated_at_utc TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            FOREIGN KEY(account_id, business_id) REFERENCES accounts(id, business_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE attachments (
            id TEXT PRIMARY KEY,
            transaction_id TEXT NOT NULL REFERENCES transactions(id),
            file_name TEXT NOT NULL,
            local_path TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
            created_at_utc TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
        await db.execute('CREATE INDEX idx_tx_business_date ON transactions(business_id, occurred_at_utc)');
        await db.execute('CREATE INDEX idx_tx_account ON transactions(account_id)');
        await db.execute('CREATE INDEX idx_attachment_tx ON attachments(transaction_id)');
        final now = DateTime.now().toUtc().toIso8601String();
        await db.insert('businesses', {'id': 'local-demo', 'name': 'My Business', 'created_at_utc': now});
        await db.insert('accounts', {'id': 'local-cash', 'business_id': 'local-demo', 'name': 'Cash', 'balance_paise': 0});
        await db.insert('accounts', {'id': 'local-bank', 'business_id': 'local-demo', 'name': 'Bank', 'balance_paise': 0});
      },
    );
  }
}
