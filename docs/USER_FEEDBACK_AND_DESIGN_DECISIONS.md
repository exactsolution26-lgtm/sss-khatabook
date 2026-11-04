# Owner feedback and design decisions — 4 November 2026

Authoritative scope: WORK_MODE_REQUIREMENTS_2026-11-04.md and IMPLEMENTATION_AND_RELEASE_GATES.md. Branch development/stability-foundation only. No main changes. No intermediate APK until requested; final APK follows implementation/review and testing.

| Feedback | Current implementation | Remaining evidence/work |
|---|---|---|
| Save gives no obvious confirmation | Opening, Income and Expense show Saving then persistent Saved with actual committed details | Physical phone acceptance; comprehensive failed-write UI tests |
| Automatic date/time/weekday | Atomic UTC save times, explicit IST English weekday/date/time; backdated accounting date separate; edit time for income | Full immutable audit across all mutations; trusted server time when available |
| Category not clickable | Income/Expense dropdown, appropriate built-ins and durable custom categories; preserves historical values | Search/filter for long category lists; full Hindi catalogue |
| Contact name/mobile from phone | Explicit native single-phone picker on Android/iOS; manual fallback; no broad address-book enumeration | Android/iOS device picker/permission/cancel verification; Web platform picker unavailable |
| Associate contact with financial entry | Normalized name/phone snapshot stored with entry; SQL-bound, tested after restart/edit; copied snapshot is independent of address-book edits | Saved-party selection/search/linking; authorization/audit |
| WhatsApp contacts and optional sharing | Native/manual fields reused; previews/opt-in/Skip retained; receipt derives stored contact and saved financial amount/time | Autofill saved recipient phone, physical WhatsApp handoff/draft-history UX; no delivery claim |
| Attractive six dashboards, no arbitrary builder | Six distinct reconstruction templates in preview-only route, each uses same data snapshot, persisted selector, Light/Dark | Owner visual approval before major main-screen activation; live tenant template management |
| English default, Hindi optional | Persisted settings, dashboard translation controls | Legacy entry/admin/errors/catalogues still need full translation |
| Preview did not load | Actual Flutter PNG fallback plus six selectable screenshot previews | Hosted Web runtime verification and interactive review |

## Category defaults
Income: Sales, Service Fees, Commission / Brokerage, Rent, Salary, Refund, Other.
Expense: Food, Groceries, Travel, Fuel, Rent, Utilities, Phone & Internet, Office Expenses, Salaries, Advertising, Repairs, Medical, Education, Bank Charges, Taxes, Other. Custom categories are separated by income/expense; transfers are not automatically classified as income.

## Rules retained
Unknown old save times remain unknown; weekday is derived from stored timestamp, never independently typed. Device-clock offline times are not server-verified audit. Only show success after DB commit. Contact/financial fields are not changed by theme/language/template switches. Opening balance locks after transactions. WhatsApp is optional and opening a draft never proves delivery. No secrets in chat, no production migration/payment activation by implication.

## Visual history
Prior conversations confirmed six fixed, switchable templates and approval of the previous demo. Exact original visuals were not recovered. Reference1002290942/43 are entry mockups,1002290956 is GitHub; broad premium showcase does not identify the six approved layouts. The owner now permits clearly labeled reconstructions. Do not describe these new six as the earlier originals.

## Verification
Source04d20783286a97cbef5cfa66ffeae06ce7e77171:68 Flutter tests and16 Python checks pass. This includes actual SQLite contact snapshots, timestamp preservation, category persistence, positive/finite amount validation, migrations and save feedback. See WORK_MODE_TEST_REPORT_2026-11-04.md for scope and limitations; no production completion certificate.
