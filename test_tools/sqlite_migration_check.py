"""SQLite migration regression checks using a v1 fixture.
Mirrors migration SQL; does not execute Flutter/Dart onUpgrade directly.
"""
import sqlite3
import unittest


def migrate_v1_to_v2(db):
    columns = {r[1] for r in db.execute("PRAGMA table_info(accounts)")}
    if "name" not in columns:
        db.execute("ALTER TABLE accounts ADD COLUMN name TEXT NOT NULL DEFAULT 'Main Account'")
    if "opening_balance" not in columns:
        db.execute("ALTER TABLE accounts ADD COLUMN opening_balance REAL NOT NULL DEFAULT 0")
        db.execute("UPDATE accounts SET opening_balance = COALESCE(cash_balance,0) + COALESCE(bank_balance,0)")
    if "created_at" not in columns:
        db.execute("ALTER TABLE accounts ADD COLUMN created_at TEXT NOT NULL DEFAULT '1970-01-01 00:00:00'")
    if "account_id" not in {r[1] for r in db.execute("PRAGMA table_info(expenses)")}:
        db.execute("ALTER TABLE expenses ADD COLUMN account_id INTEGER REFERENCES accounts(id)")
    db.execute("""CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL,
        amount REAL NOT NULL, description TEXT, date TEXT NOT NULL,
        created_at TEXT NOT NULL, FOREIGN KEY(account_id) REFERENCES accounts(id))""")
    db.execute("""CREATE TABLE work (
        id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
        start_time TEXT, end_time TEXT, duration INTEGER NOT NULL DEFAULT 0,
        description TEXT, created_at TEXT NOT NULL)""")


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("CREATE TABLE accounts (id INTEGER PRIMARY KEY, cash_balance REAL, bank_balance REAL)")
        self.db.execute("""CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL,
            mode TEXT, category TEXT, note TEXT, date TEXT)""")
        self.db.execute("INSERT INTO accounts VALUES (7,125.25,300.75)")
        self.db.execute("INSERT INTO expenses VALUES (11,20.5,'cash','food','legacy','2026-10-01')")

    def tearDown(self):
        self.db.close()

    def test_existing_rows_and_ids_survive(self):
        migrate_v1_to_v2(self.db)
        self.assertEqual(
            self.db.execute("SELECT id, cash_balance, bank_balance, opening_balance FROM accounts").fetchall(),
            [(7, 125.25, 300.75, 426.0)],
        )
        self.assertEqual(
            self.db.execute("SELECT id, amount, account_id FROM expenses").fetchall(),
            [(11, 20.5, None)],
        )
        self.assertEqual(
            {r[0] for r in self.db.execute("SELECT name FROM sqlite_master WHERE type='table'")},
            {"accounts", "expenses", "income", "work", "sqlite_sequence"},
        )
        self.assertEqual(self.db.execute("PRAGMA integrity_check").fetchone()[0], "ok")

    def test_new_income_references_existing_account(self):
        migrate_v1_to_v2(self.db)
        self.db.execute("INSERT INTO income (account_id,amount,date,created_at) VALUES (7,10,'2026-11-03','2026-11-03')")
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM income").fetchone()[0], 1)
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO income (account_id,amount,date,created_at) VALUES (99,10,'2026-11-03','2026-11-03')")


if __name__ == "__main__":
    unittest.main()
