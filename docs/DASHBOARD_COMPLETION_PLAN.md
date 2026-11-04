# Six-dashboard completion — numbered scope and review

Owner request: complete pending item 1 (six dashboards), add useful related points, plan in serial order, analyse, implement, check and test. The owner still prohibits a new APK. Work is confined to development/stability-foundation; no main changes.

## Recovery and scope decision

Repository/history and conversation retrieval did not recover exact six approved visual layouts or per-layout approval records. The six existing reconstructions are Classic, Balance Focus, Compact, Overview, Accounts and Timeline. Reuse these; do not present them as recovered approved originals. The owner now requests completion. Previewing a reconstruction must not change the active design: explicitly selecting **Use this dashboard** activates it. No seventh template, arbitrary builder, template-creation API, role grant or cloud platform UI is introduced.

## Serial plan and acceptance

1. **Connect home** — the real home uses the persisted six-value enum, one layout at a time.
2. **Preview then apply** — separate transient preview selection from explicit activation. Back cancels an unapplied choice; show genuine save feedback and save errors.
3. **Persistent choice** — show the active name, restore after restart, keep latest of rapid changes; invalid stored IDs fall back to Classic.
4. **Preserve ledger** — all layouts consume one read-only SQLite summary. Compare every database table before/after switches; no schema migration or financial write is required.
5. **History navigation** — Income and Expenses metrics open their typed histories. Keep Add Income/Add Expense as explicit separate actions.
6. **Recent entries** — bounded recent records with transaction weekday/date, original saved IST timestamp, contact snapshot, account and notes; open the exact type/id/account. Do not invent legacy timestamps. Sort by transaction date, then saved time and deterministic identity.
7. **Account navigation** — show up to five account balances, open the chosen ledger, and provide View all accounts with the actual count.
8. **Hide amounts** — persist an optional dashboard-only presentation preference. Hide summary/account/recent amounts, note text and comparison bars. It is not an app security lock; other financial screens remain accessible.
9. **Responsive presentation** — retain six distinct arrangements and existing Light/Dark themes, translate dashboard controls to Hindi, test 320px with 200% text and 1200px desktop. Existing shared date formatter uses English weekday/month names; full app localization is a separate gate.
10. **Honest states and calculations** — loading indicator, no fabricated zero fallback on failure, retry, empty records, all-time/local-device scope label, explicit unassigned historic expense notice. No unverified dues or platform revenue values.
11. **Keep existing tools** — work timer, dues/partial payments, follow-ups, reports, opening balances, WhatsApp drafts, settings and simulated Super Admin preview stay reachable. The Super Admin preview remains explicitly simulated and is not an authorization grant.
12. **Verify and record** — real SQLite/widget/setting tests, six-by-two-theme Flutter captures, web compile and actual browser preview/cancel/apply plus offline restart, existing security/financial/backup regression checks. Record run/commit evidence and failures honestly. No APK jobs.

## Analysis and error review

- Root cause: the preview screen wrote a preference immediately, while DashboardScreen never rendered that preference. Decouple preview selection from persistence, and share DashboardTemplateView between preview and home.
- Use one finance snapshot, not six independent summary queries/calculation implementations. Keep legacy unassigned expenses included in global totals without assigning another customer's identity.
- Income and expense IDs can collide. Entry navigation must pass the source kind as well as ID and account; tests use matching IDs in both tables.
- Date is the accounting date; created_at is original save time. Neither preview nor preference writes may update these fields. Missing historic timezone must stay unknown.
- A UI setting may apply in memory even if durable storage fails. Do not show a saved confirmation in this case; allow retry and show the session-only state.
- Large account/transaction lists cannot be eagerly displayed in full on a dashboard. Bound visible cards and link to full screens; all-time summaries still include all records.
- The current local app has one workspace. These preferences are local-profile settings, not verified authenticated subscriber-scoped backend storage. Tenant partition/auth sync and Super Admin template management remain separate unfinished gates.
- Current original-design identity/approval, real Samsung A14 acceptance, live backend authorization and production readiness cannot be certified by widget/browser tests.

## Execution evidence

Implementation/tests in this increment. Final verified commit, CI counts, screenshots and remaining gates are recorded in SIX_DASHBOARD_IMPLEMENTATION_STATUS.md after verification. Do not interpret this plan itself as passing results.
