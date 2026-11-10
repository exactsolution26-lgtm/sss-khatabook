"""Measure the app history SQL on 200,000 synthetic records for 10,000 local accounts.

Run from any directory with Python 3. Results are single-client SQLite timings.
"""

from pathlib import Path
import sqlite3
import statistics
import tempfile
from time import perf_counter

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/features/analysis/analysis_logic.dart').read_text()
schema = (root / 'lib/database/db_helper.dart').read_text()
index_templates = [
    line.split("'")[1]
    for line in schema.splitlines()
    if "await db.execute('CREATE INDEX IF NOT EXISTS ${table}_history_" in line
]
assert len(index_templates) == 2
template = source.split("return db.rawQuery('''", 1)[1].split("'''", 1)[0]
with tempfile.TemporaryDirectory() as temp:
    conn = sqlite3.connect(Path(temp) / 'synthetic.db')
    conn.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY)')
    conn.executemany('INSERT INTO accounts VALUES (?)', ((i,) for i in range(1, 10001)))
    for table, note in [('income', 'description'), ('expenses', 'note')]:
        conn.execute(f'CREATE TABLE {table}(id INTEGER PRIMARY KEY, account_id INTEGER REFERENCES accounts(id), amount REAL, date TEXT, created_at TEXT, {note} TEXT, category TEXT, mode TEXT)')
        conn.executemany(f'INSERT INTO {table} VALUES (?,?,?,?,?,?,?,?)',
                         ((i, (i-1)%10000+1, 1.25, f'2026-{1+(i//10000)%10:02d}-01', None, None, 'test', 'cash') for i in range(1, 100001)))
    conn.commit()
    baseline = {}
    for indexed in (False, True):
        if indexed:
            for table in ('income', 'expenses'):
                for index in index_templates:
                    conn.execute(index.replace('${table}', table).replace('$table', table))
        for label, account_id in [('global', None), ('account', 1985)]:
            base = ['account_id=?'] if account_id is not None else []
            base_args = [account_id] if account_id is not None else []
            samples, pages, seen = [], [], set()
            for _ in range(10):
                if pages:
                    key, date, kind = pages[-1][-1][0], pages[-1][-1][3], pages[-1][-1][-1]
                    cursor = ['(date < ? OR (date = ? AND kind > ?) OR (date = ? AND kind = ? AND id < ?))']
                    args = [date, date, kind, date, kind, key]
                else:
                    cursor, args = [], []
                terms = base + cursor
                query = template.replace('$filter', 'WHERE ' + ' AND '.join(terms) if terms else '')
                started = perf_counter()
                rows = conn.execute(query, [*base_args, *args, 10]).fetchall()
                samples.append((perf_counter() - started) * 1000)
                if not rows:
                    break
                if account_id is not None:
                    assert all(row[1] == account_id for row in rows)
                for row in rows:
                    identity = (row[-1], row[0])
                    assert identity not in seen
                    seen.add(identity)
                pages.append(rows)
            assert len(seen) == (20 if account_id else 100)
            if indexed:
                assert pages == baseline[label]
            else:
                baseline[label] = pages
            print(f'SQLite {sqlite3.sqlite_version}, index={indexed}, {label}: {len(seen)} rows in {len(pages)} pages, median {statistics.median(samples):.2f} ms, max {max(samples):.2f} ms')
