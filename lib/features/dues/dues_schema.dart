import 'package:sqflite/sqflite.dart';

class DuesSchema {
  static Future<void> install(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS obligations (
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL REFERENCES accounts(id),
      kind TEXT NOT NULL CHECK(kind IN ('receivable','payable')),
      total_paise INTEGER NOT NULL CHECK(typeof(total_paise)='integer' AND total_paise BETWEEN 1 AND 9000000000000),
      description TEXT NOT NULL, due_date TEXT, contact_name TEXT, contact_phone TEXT,
      created_at TEXT NOT NULL, updated_at TEXT
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS payment_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT, obligation_id INTEGER NOT NULL REFERENCES obligations(id),
      amount_paise INTEGER NOT NULL CHECK(typeof(amount_paise)='integer' AND amount_paise BETWEEN 1 AND 9000000000000),
      income_id INTEGER UNIQUE REFERENCES income(id), expense_id INTEGER UNIQUE REFERENCES expenses(id),
      operation_key TEXT NOT NULL UNIQUE CHECK(length(operation_key)=32), mode TEXT NOT NULL CHECK(mode IN ('cash','bank','upi','card')), note TEXT NOT NULL,
      created_at TEXT NOT NULL, reversed_at TEXT, reversal_reason TEXT,
      reversal_income_id INTEGER UNIQUE REFERENCES income(id), reversal_expense_id INTEGER UNIQUE REFERENCES expenses(id),
      CHECK((income_id IS NULL) != (expense_id IS NULL))
    )''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_limit BEFORE INSERT ON payment_allocations
      WHEN NEW.reversed_at IS NULL AND NEW.amount_paise > (SELECT total_paise-COALESCE((SELECT SUM(amount_paise) FROM payment_allocations
        WHERE obligation_id=NEW.obligation_id AND reversed_at IS NULL),0) FROM obligations WHERE id=NEW.obligation_id)
      BEGIN SELECT RAISE(ABORT,'Payment exceeds remaining amount'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_owner BEFORE INSERT ON payment_allocations
      WHEN NOT EXISTS(SELECT 1 FROM obligations o WHERE o.id=NEW.obligation_id AND
        ((o.kind='receivable' AND NEW.expense_id IS NULL AND EXISTS(SELECT 1 FROM income i WHERE i.id=NEW.income_id
          AND i.account_id=o.account_id AND round(i.amount*100)=NEW.amount_paise)) OR
         (o.kind='payable' AND NEW.income_id IS NULL AND EXISTS(SELECT 1 FROM expenses e WHERE e.id=NEW.expense_id
          AND e.account_id=o.account_id AND round(e.amount*100)=NEW.amount_paise))))
      BEGIN SELECT RAISE(ABORT,'Payment does not match this account and entry'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_immutable BEFORE UPDATE ON payment_allocations
      WHEN NEW.amount_paise IS NOT OLD.amount_paise OR NEW.obligation_id IS NOT OLD.obligation_id
        OR NEW.income_id IS NOT OLD.income_id OR NEW.expense_id IS NOT OLD.expense_id
        OR NEW.operation_key IS NOT OLD.operation_key OR OLD.reversed_at IS NOT NULL
      BEGIN SELECT RAISE(ABORT,'Recorded allocation cannot be changed'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_reversal_match BEFORE UPDATE ON payment_allocations
      WHEN NEW.reversed_at IS NULL OR NEW.reversal_reason IS NULL OR length(trim(NEW.reversal_reason))=0
        OR NOT EXISTS(SELECT 1 FROM obligations o WHERE o.id=NEW.obligation_id AND
        ((o.kind='receivable' AND NEW.reversal_income_id IS NULL AND EXISTS(SELECT 1 FROM expenses e WHERE e.id=NEW.reversal_expense_id AND e.account_id=o.account_id AND round(e.amount*100)=NEW.amount_paise)) OR
        (o.kind='payable' AND NEW.reversal_expense_id IS NULL AND EXISTS(SELECT 1 FROM income i WHERE i.id=NEW.reversal_income_id AND i.account_id=o.account_id AND round(i.amount*100)=NEW.amount_paise))))
      BEGIN SELECT RAISE(ABORT,'Reversal requires a matching counter entry'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_reversal_restore BEFORE INSERT ON payment_allocations
      WHEN NEW.reversed_at IS NOT NULL AND (NEW.reversal_reason IS NULL OR length(trim(NEW.reversal_reason))=0
        OR NOT EXISTS(SELECT 1 FROM obligations o WHERE o.id=NEW.obligation_id AND
        ((o.kind='receivable' AND NEW.reversal_income_id IS NULL AND EXISTS(SELECT 1 FROM expenses e WHERE e.id=NEW.reversal_expense_id AND e.account_id=o.account_id AND round(e.amount*100)=NEW.amount_paise)) OR
        (o.kind='payable' AND NEW.reversal_expense_id IS NULL AND EXISTS(SELECT 1 FROM income i WHERE i.id=NEW.reversal_income_id AND i.account_id=o.account_id AND round(i.amount*100)=NEW.amount_paise)))))
      BEGIN SELECT RAISE(ABORT,'Restored reversal does not match its counter entry'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_no_delete BEFORE DELETE ON payment_allocations
      BEGIN SELECT RAISE(ABORT,'Reverse a recorded payment instead of deleting it'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_cash_unique BEFORE INSERT ON payment_allocations
      WHEN (NEW.income_id IS NOT NULL AND EXISTS(SELECT 1 FROM payment_allocations WHERE reversal_income_id=NEW.income_id))
        OR (NEW.expense_id IS NOT NULL AND EXISTS(SELECT 1 FROM payment_allocations WHERE reversal_expense_id=NEW.expense_id))
        OR (NEW.reversal_income_id IS NOT NULL AND EXISTS(SELECT 1 FROM payment_allocations WHERE income_id=NEW.reversal_income_id OR reversal_income_id=NEW.reversal_income_id))
        OR (NEW.reversal_expense_id IS NOT NULL AND EXISTS(SELECT 1 FROM payment_allocations WHERE expense_id=NEW.reversal_expense_id OR reversal_expense_id=NEW.reversal_expense_id))
      BEGIN SELECT RAISE(ABORT,'Cash entry is already allocated'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS payment_reversal_cash_unique BEFORE UPDATE ON payment_allocations
      WHEN (NEW.reversal_income_id IS NOT NULL AND EXISTS(SELECT 1 FROM payment_allocations WHERE id!=OLD.id AND (income_id=NEW.reversal_income_id OR reversal_income_id=NEW.reversal_income_id)))
        OR (NEW.reversal_expense_id IS NOT NULL AND EXISTS(SELECT 1 FROM payment_allocations WHERE id!=OLD.id AND (expense_id=NEW.reversal_expense_id OR reversal_expense_id=NEW.reversal_expense_id)))
      BEGIN SELECT RAISE(ABORT,'Counter entry is already allocated'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS obligation_paid_guard BEFORE UPDATE ON obligations
      WHEN NEW.account_id IS NOT OLD.account_id OR NEW.kind IS NOT OLD.kind OR
        NEW.total_paise < (SELECT COALESCE(SUM(amount_paise),0) FROM payment_allocations WHERE obligation_id=OLD.id AND reversed_at IS NULL)
      BEGIN SELECT RAISE(ABORT,'Account, direction or settled amount cannot be changed'); END''');
    for (final table in ['income','expenses']) {
      final field = table == 'income' ? 'income_id' : 'expense_id';
      await db.execute('''CREATE TRIGGER IF NOT EXISTS ${table}_allocated_amount BEFORE UPDATE ON $table
        WHEN (NEW.amount IS NOT OLD.amount OR NEW.account_id IS NOT OLD.account_id) AND
          EXISTS(SELECT 1 FROM payment_allocations WHERE $field=OLD.id OR reversal_$field=OLD.id)
        BEGIN SELECT RAISE(ABORT,'Reverse the linked payment before changing it'); END''');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS allocations_due ON payment_allocations(obligation_id)');
  }
}
