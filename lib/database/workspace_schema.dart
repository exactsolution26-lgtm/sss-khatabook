/// Phase 1 local schema for independently scoped personal/business workspaces.
/// This is an additive design, not a substitute for server-side authorization.
class WorkspaceSchema {
  static const statements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS workspace_users (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      created_at_utc TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS workspaces (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL REFERENCES workspace_users(id),
      kind TEXT NOT NULL CHECK(kind IN ('personal', 'business')),
      display_name TEXT NOT NULL,
      created_at_utc TEXT NOT NULL,
      UNIQUE(id, owner_user_id)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS workspace_memberships (
      user_id TEXT NOT NULL REFERENCES workspace_users(id),
      workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      role TEXT NOT NULL CHECK(role IN ('owner','admin','accountant','staff','viewer')),
      PRIMARY KEY(user_id, workspace_id)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS workspace_parties (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL,
      UNIQUE(id, workspace_id)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS workspace_accounts (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL,
      opening_balance_paise INTEGER NOT NULL DEFAULT 0,
      UNIQUE(id, workspace_id),
      UNIQUE(workspace_id, name)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS workspace_entries (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      account_id TEXT NOT NULL,
      party_id TEXT,
      kind TEXT NOT NULL CHECK(kind IN ('income','expense','transfer_in','transfer_out')),
      amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
      idempotency_key TEXT NOT NULL,
      occurred_at_utc TEXT NOT NULL,
      created_at_utc TEXT NOT NULL,
      UNIQUE(workspace_id, idempotency_key),
      FOREIGN KEY(account_id, workspace_id)
        REFERENCES workspace_accounts(id, workspace_id),
      FOREIGN KEY(party_id, workspace_id)
        REFERENCES workspace_parties(id, workspace_id)
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_workspace_entries_scope ON workspace_entries(workspace_id, occurred_at_utc)',
    'CREATE INDEX IF NOT EXISTS idx_workspace_parties_scope ON workspace_parties(workspace_id, name)'
  ];
}
