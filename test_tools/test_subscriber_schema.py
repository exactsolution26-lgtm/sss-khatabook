import pathlib
import unittest

SQL = (pathlib.Path(__file__).resolve().parents[1] /
       "supabase/migrations/202611040001_subscriber_accounts.sql").read_text()

class SubscriberSchemaTests(unittest.TestCase):
    def test_rls_enabled_on_all_tables(self):
        for table in ("platform_admins", "subscriber_accounts", "subscriber_account_audit"):
            self.assertIn(f"alter table public.{table} enable row level security;", SQL)

    def test_only_platform_admin_can_modify_accounts(self):
        self.assertIn("for insert to authenticated with check ((select public.is_platform_admin()))", SQL)
        self.assertIn("for update to authenticated", SQL)
        self.assertIn("with check ((select public.is_platform_admin()))", SQL)

    def test_subscribers_can_only_read_their_account(self):
        self.assertIn("owner_user_id = (select auth.uid())", SQL)
        self.assertIn("grant update (display_name, status)", SQL)
        self.assertNotIn("for delete to authenticated", SQL)

    def test_admin_registry_and_audit_not_client_writable(self):
        self.assertIn("revoke all on public.platform_admins from anon, authenticated", SQL)
        self.assertIn("revoke all on public.subscriber_account_audit from anon, authenticated", SQL)
        self.assertIn("create trigger subscriber_account_audit_trigger", SQL)

if __name__ == "__main__":
    unittest.main()
