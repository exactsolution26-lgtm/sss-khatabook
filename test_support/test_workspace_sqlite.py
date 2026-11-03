import sqlite3
import unittest

SCHEMA = [
"""CREATE TABLE workspace_users(id TEXT PRIMARY KEY, display_name TEXT NOT NULL, created_at_utc TEXT NOT NULL)""",
"""CREATE TABLE workspaces(id TEXT PRIMARY KEY, owner_user_id TEXT NOT NULL REFERENCES workspace_users(id), kind TEXT NOT NULL CHECK(kind IN ('personal','business')), display_name TEXT NOT NULL, created_at_utc TEXT NOT NULL, UNIQUE(id,owner_user_id))""",
"""CREATE TABLE workspace_memberships(user_id TEXT NOT NULL REFERENCES workspace_users(id),workspace_id TEXT NOT NULL REFERENCES workspaces(id),role TEXT NOT NULL CHECK(role IN ('owner','admin','accountant','staff','viewer')),PRIMARY KEY(user_id,workspace_id))""",
"""CREATE TABLE workspace_parties(id TEXT PRIMARY KEY,workspace_id TEXT NOT NULL REFERENCES workspaces(id),name TEXT NOT NULL,UNIQUE(id,workspace_id))""",
"""CREATE TABLE workspace_accounts(id TEXT PRIMARY KEY,workspace_id TEXT NOT NULL REFERENCES workspaces(id),name TEXT NOT NULL,opening_balance_paise INTEGER NOT NULL DEFAULT 0,UNIQUE(id,workspace_id),UNIQUE(workspace_id,name))""",
"""CREATE TABLE workspace_entries(id TEXT PRIMARY KEY,workspace_id TEXT NOT NULL REFERENCES workspaces(id),account_id TEXT NOT NULL,party_id TEXT,kind TEXT NOT NULL CHECK(kind IN ('income','expense','transfer_in','transfer_out')),amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),idempotency_key TEXT NOT NULL,occurred_at_utc TEXT NOT NULL,created_at_utc TEXT NOT NULL,UNIQUE(workspace_id,idempotency_key),FOREIGN KEY(account_id,workspace_id) REFERENCES workspace_accounts(id,workspace_id),FOREIGN KEY(party_id,workspace_id) REFERENCES workspace_parties(id,workspace_id))"""
]
class WorkspaceIsolationTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        for sql in SCHEMA:
            self.db.execute(sql)
        for user,space in [('u1','personal1'),('u2','business2')]:
            self.db.execute('INSERT INTO workspace_users VALUES(?,?,?)',(user,user,'2026-11-03'))
            self.db.execute('INSERT INTO workspaces VALUES(?,?,?,?,?)',(space,user,'personal' if user=='u1' else 'business',space,'2026-11-03'))
            self.db.execute('INSERT INTO workspace_accounts VALUES(?,?,?,?)',('a'+user,space,'Cash',0))
            self.db.execute('INSERT INTO workspace_parties VALUES(?,?,?)',('p'+user,space,'Party'))
    def insert(self, entry='e1', workspace='personal1', account='au1', party='pu1', key='key1', amount=100):
        self.db.execute('INSERT INTO workspace_entries VALUES(?,?,?,?,?,?,?,?,?)',(entry,workspace,account,party,'income',amount,key,'2026-11-03','2026-11-03'))
    def test_valid_personal_entry(self): self.insert()
    def test_reject_cross_workspace_account(self):
        with self.assertRaises(sqlite3.IntegrityError): self.insert(account='au2')
    def test_reject_cross_workspace_party(self):
        with self.assertRaises(sqlite3.IntegrityError): self.insert(party='pu2')
    def test_reject_duplicate_idempotency_key(self):
        self.insert()
        with self.assertRaises(sqlite3.IntegrityError): self.insert(entry='e2')
    def test_reject_zero_amount(self):
        with self.assertRaises(sqlite3.IntegrityError): self.insert(amount=0)
    def test_independent_workspace_balances(self):
        self.insert()
        self.insert('e2','business2','au2','pu2','key2',300)
        values = self.db.execute('SELECT workspace_id,SUM(amount_paise) FROM workspace_entries GROUP BY workspace_id').fetchall()
        self.assertEqual(values,[('business2',300),('personal1',100)])
    def test_reject_invalid_workspace_kind(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO workspaces VALUES('bad','u1','other','bad','2026-11-03')")
if __name__ == '__main__':
    unittest.main()
