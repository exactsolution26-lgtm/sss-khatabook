# Financial calculation correctness — mandatory acceptance criteria

Status: requirements and test plan; NOT yet verified or implemented.

## Invariants
- Store financial amounts as signed integer paise or an exact decimal with a documented rounding policy. Never use binary floating point as the canonical source of truth.
- Parse rupee input as decimal text; reject malformed input, NaN, infinity, excess decimal places, out-of-range values and unintended negatives. Display INR with exactly two decimal places when needed.
- Transaction balances reconcile to opening balance + qualifying inflows - qualifying outflows, scoped by account, business and date window.
- Transfers between own accounts affect account balances but do not count as income or expense. Reversals are explicit and auditable.
- Dashboard, ledger, exports and charts use the same authorized, filtered calculation rules.
- Edits, voids, refunds, partial payments, receivables, payables and backdated entries must reconcile without double counting.
- Multi-tenant separation and permission filters apply before aggregation.
- Offline retry and cloud sync must be idempotent with stable transaction IDs and deterministic conflict resolution.
- Date grouping is based on Asia/Kolkata business dates while storing UTC instants; test midnight boundary and timezone changes.
- Attachments never alter financial totals; optional WhatsApp/download/share must not mutate ledger amounts.
- No silent deletion of records, rounding adjustments, or reclassification.

## Required test fixtures
1. 0.10 + 0.20 = 0.30 exactly; 999999.99 + 0.01 = 1000000.00.
2. Opening 1000, income 500, expense 200 => 1300.
3. Transfer 300 cash-to-bank: combined total unchanged, each account moves 300.
4. Expense edit 200 -> 250: balance decreases by 50 exactly, not 250 twice.
5. Void an expense: its effect is reversed once; repeated void is idempotent.
6. Sync same UUID repeatedly: one posted transaction, one financial effect.
7. Cash vs UPI/bank reconciliation, partial receipts, refunds, category and date filters.
8. Cross-midnight IST reporting, leap day, monthly/yearly boundaries.
9. Exports and charts match ledger aggregate to the paise.
10. Simulated concurrent edits, rollback, restore, and 10,000 registered-user workload with measured concurrency.

## Verification gates
- Unit tests for money parsing, arithmetic, totals and reconciliation.
- Repository integration tests for migrations, transaction atomicity, conflict handling and tenant isolation.
- UI/widget tests for validation, dashboard consistency, filters, and user feedback.
- Property-based / randomized reconciliation tests, plus benchmarked load profiles.
- No claim of correctness or readiness until executable checks pass; final end-to-end testing follows feature completion, with incremental developer checks to avoid accumulating defects.

## Existing code risks
- Legacy SQLite schema stores REAL; requires backup and a safe migration to exact monetary representation.
- Existing opening-balance UI silently maps invalid input to zero.
- Existing expense UI silently maps invalid input to zero.
- No actual Flutter tests or load tests have been executed in this work session.
