# SSS Khatabook — owner requirements, 4 November 2026

This is the current implementation contract, preserving earlier approved scope. Read alongside IMPLEMENTATION_AND_RELEASE_GATES.md; no redesign from scratch. Work only on development/stability-foundation. Never modify or merge main without explicit permission.

## Dashboard and design approval
Exactly six selectable fixed templates, one active per subscriber, switchable without changing financial records. No unlimited creation or subscriber builder; only Global Super Admin may add platform templates. Light/Dark and responsive Android/Web, iOS compatibility planned. Recover original approved layouts from history/assets. When unrecoverable, present explicitly labeled reconstruction previews for visual approval. Never claim new layouts were previously approved. Previewing reconstructions is authorized; activating major redesigned screens requires visual approval.

## Financial entry
Income/Expense selection, numeric amount, clickable appropriate category options, customer/party, name/mobile snapshot from chosen contact where supported, manual fallback, payment mode, India date/calendar and save time/weekday, notes and optional attachments. View/download/share attachments. Authorized save/edit/delete, correct balances, full transaction history. Preserve original save time and separate edit time; never invent missing historic times. Contact-book changes must not rewrite financial snapshots. Use numeric/phone/text/calendar controls appropriately. Show Saving, committed Saved feedback, and actual saved details. Do not show success before persistence.

## Previously approved product features
Automatic backup and restore; partial payments/remaining amounts; optional WhatsApp; customer ledger PDF; PIN/biometric security; IST audit history; Hindi/English voice entry with confirmation; follow-ups, due dates and reminders. Attachments and contact permissions are platform-specific. Local phone testing must work without Supabase; SaaS requires real backend verification.

## Accounts and subscriptions
One Global Super Admin (platform owner): subscribers, plans, prices/discounts, verified payments/renewals, revenue/reports, platform settings and template management. Subscriber Admin: only own customers, transactions, ledger, reports, subscription and settings. Prevent cross-subscriber access. Start at INR99/month; owner-adjustable prices, fixed/percentage discounts, validity dates, original price/discount/savings/final price, expiry/renewal and secure payment verification/access control.

## Offline, locale and sharing
Cryptographically verified 30-day offline authorization lease, secure offline data, online synchronization, conflicts without lost/mixed records. English default across platform, Hindi optional per subscriber; persistent theme/language/template preferences, INR and IST formatting. WhatsApp ledger, reminders, receipts, monthly statements, subscription reminders/custom messages; preview, optional Send/Skip, IST and draft history. Opening WhatsApp never proves delivery.

## Test and release gates
First stabilize Android red screen; inspect existing commits/screens/docs/Actions and use dependency order. Complete the approved58 tasks; test each module and combined regression. Actual authentication/authorization/RLS/privacy/security, backup/recovery, offline sync and financial calculations/cross-user leakage tests. Representative10,000-user testing when infrastructure exists. Fix/retest failures, retain SHA/CI/logs; never fabricate results. External Supabase/merchant/signing/device dependencies are BLOCKED, not passed; continue independent work.

## Required visual review and delivery
Six separately selectable previews; working Income/Expense, categories/contacts, theme/language switches, Subscriber and Super Admin. Explicitly label simulated behavior/data. Final delivery after implementation includes genuine tests, verified latest APK/download link, Web status, Completed/Pending/Blocked counts, commits and CI. Never describe an unverified APK as production-ready. Earlier APK hold remains in effect during this visual-review increment; the owner requests the final APK after implementation, not an immediate intermediate build.
