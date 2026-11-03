# Personal and Business Khata — required account model

## Product behavior
A signed-in user may create one or more separate Khata workspaces:
- PERSONAL: an individual's own finances, cash/bank balances, money lent/borrowed, and person-wise ledgers.
- BUSINESS: each registered business or shop's independent cash/bank, income, expenses, parties, staff, and reports.

A user can own multiple businesses and switch between PERSONAL and BUSINESS workspaces without merging any balances, transactions, parties, attachments or reports. Each person/contact in either workspace has its own ledger and due/advance balance. A contact may exist in multiple workspaces but its transactions must remain workspace-specific.

## Required data model
- users: authenticated user ID
- workspaces: workspace ID, kind PERSONAL|BUSINESS, display name, owner user ID
- workspace_memberships: user ID, workspace ID, role
- parties: party ID, workspace ID, display name, contact details
- accounts: account ID, workspace ID, type cash|bank, opening balance in integer paise
- transactions: transaction ID, workspace ID, account ID, optional party ID, type, signed accounting effect, integer paise, timestamps, idempotency key
- attachments: workspace-scoped transaction and authorized object references
- sync queue: workspace ID, stable transaction ID, retry and conflict state

The existing businesses table and local-demo ID are temporary scaffolding; they do NOT satisfy these requirements.

## Security and consistency
- Authenticate and authorize every workspace access on the server; enforce membership and role in DB RLS.
- Composite FKs ensure account/party/transaction workspace consistency.
- Use one source of truth for balances, and atomic immutable ledger postings with explicit reversal for corrections.
- Reconcile party balances and workspace totals to paise; no duplicates on retries.
- Workspace switch clears or partitions cached state and pending queries.
- UI must display current workspace name and type prominently on every entry form.
- Never assume a person ledger is a separate tenant; it is a party ledger scoped within a workspace.

## Acceptance tests
- Personal A cannot see Business A transactions; Business A cannot see Business B.
- User A cannot access User B's personal workspace, including by guessed IDs.
- Person Rahul's ledger cannot include Amit's entries.
- Cross-workspace account/party attachment references are rejected.
- Offline retries never duplicate entries or silently lose them.
- Each workspace has independent dashboard totals, export, search, backup and sync.

Implementation status: SPECIFICATION ONLY. No claim of completed cloud auth or production isolation.
