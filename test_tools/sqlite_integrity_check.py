"""Execute the SQL trigger strings from the Dart source in SQLite.
This checks SQL behavior, not execution of Dart's migration callback.
"""
from pathlib import Path
import re
import sqlite3
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'lib/database/db_helper.dart').read_text()


def install_actual_guard_sql(db):
    opening = re.search(r"'''(CREATE TRIGGER account_opening_lock.*?)'''", SOURCE, re.S).group(1)
    db.execute(opening)
    template = re.search(r"'''(CREATE TRIGGER \$\{table\}_.*?)'''", SOURCE, re.S).group(1)
    for table in ('income', 'expenses'):
        for operation in ('INSERT', 'UPDATE'):
            sql = template.replace('${table}', table).replace('${operation.toLowerCase()}', operation.lower())
            sql = sql.replace('$operation', operation).replace('$table', table)
            db.execute(sql)


class IntegrityGuards(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY,name TEXT,opening_balance REAL,cash_balance REAL,bank_balance REAL,archived_at TEXT)')
        for table in ('income', 'expenses'):
            self.db.execute(f'CREATE TABLE {table}(id INTEGER PRIMARY KEY,account_id INTEGER REFERENCES accounts(id),amount REAL)')
        self.db.execute("INSERT INTO accounts VALUES(1,'A',100,50,50,NULL)")
        self.db.execute('INSERT INTO expenses VALUES(10,NULL,20)')
        install_actual_guard_sql(self.db)

    def tearDown(self):
        self.db.close()

    def test_legacy_unassigned_rows_are_preserved(self):
        self.assertEqual(self.db.execute('SELECT * FROM expenses').fetchall(), [(10, None, 20)])

    def test_missing_account_rejected(self):
        for table in ('income', 'expenses'):
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f'INSERT INTO {table}(amount) VALUES (12)')

    def test_bad_amounts_rejected_on_insert(self):
        for table in ('income', 'expenses'):
            for amount in (None, 0, -1, float('nan'), float('inf'), 90000000000001):
                with self.subTest(table=table, amount=amount):
                    with self.assertRaises(sqlite3.IntegrityError):
                        self.db.execute(f'INSERT INTO {table}(account_id,amount) VALUES(1,?)', (amount,))

    def test_bad_amounts_rejected_on_update(self):
        self.db.execute('INSERT INTO income VALUES(1,1,10)')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE income SET amount=-10 WHERE id=1')

    def test_opening_lock_enforced_after_income(self):
        self.db.execute('INSERT INTO income VALUES(1,1,10)')
        for column in ('opening_balance', 'cash_balance', 'bank_balance'):
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f'UPDATE accounts SET {column}=200 WHERE id=1')
        self.db.execute("UPDATE accounts SET name='Renamed' WHERE id=1")
        self.assertEqual(self.db.execute('SELECT opening_balance FROM accounts').fetchone(), (100,))

    def test_opening_lock_enforced_after_expense(self):
        self.db.execute('INSERT INTO expenses VALUES(2,1,10)')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE accounts SET opening_balance=200 WHERE id=1')

    def test_archive_blocks_financial_writes_and_restore_reenables_them(self):
        self.db.execute('INSERT INTO income VALUES(1,1,10)')
        self.db.execute("UPDATE accounts SET archived_at='2026-11-06T00:00:00Z' WHERE id=1")
        for table in ('income', 'expenses'):
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f'INSERT INTO {table}(account_id,amount) VALUES(1,5)')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE income SET amount=20 WHERE id=1')
        self.assertEqual(self.db.execute('SELECT amount FROM income WHERE id=1').fetchone(), (10,))
        self.db.execute('UPDATE accounts SET archived_at=NULL WHERE id=1')
        self.db.execute('INSERT INTO expenses(account_id,amount) VALUES(1,5)')

    def test_unknown_account_rejected(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO income VALUES(1,99,10)')

    def test_opening_can_change_before_first_transaction(self):
        self.db.execute('UPDATE accounts SET opening_balance=200 WHERE id=1')
        self.assertEqual(self.db.execute('SELECT opening_balance FROM accounts').fetchone(), (200,))

if __name__ == '__main__':
    unittest.main()
