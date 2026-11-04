# User feedback and design decisions — SSS Khatabook

Updated: 4 November 2026, India Standard Time.
Branch: development/stability-foundation. Do not modify or merge main.

## Active user restrictions
- Do NOT build a new APK until the user explicitly requests it.
- Review proposed visual designs before implementing the final interface.
- Test locally on the phone without Supabase first; hosted SaaS setup is deferred.
- Application-code pushes currently trigger Android builds. Before any future application-code push, gate those jobs behind an explicit manual build request. Do not inadvertently trigger a build while making these requested changes.
- This documentation-only checkpoint uses [skip ci]. It does not implement or certify the items below.

## Confirmed language decision
English is the default language for the entire platform. Hindi is optional and selected by the user.
This covers Android and Web screens, navigation, form labels, categories, validation/errors, save confirmations, reports, receipts, sharing templates and date/weekday display. Persist the chosen language. Numeric data, contacts and financial records must retain their original values when language changes.

## Feedback register
| ID | User observation/request | Intended behavior | State |
|---|---|---|---|
| UX-01 | Opening Balance saves but confirmation is not obvious | Visible Saving state, persistent Saved confirmation with actual saved amounts, clear failure state; do not claim success before database commit | Requested; code draft prepared, not pushed or verified |
| UX-02 | Date, time and weekday must save automatically with every amount entry | Apply consistently to Opening Balance, Income and Expense; retain immutable original save time and a separate last-edit time | Requested; opening-only draft exists, comprehensive implementation pending |
| UX-03 | Example display is 4 November 2026, Wednesday, with time | English default: Wednesday, 4 November 2026 · 08:07:32 AM IST; derive date/weekday from the stored instant; UTC storage and explicit Asia/Kolkata display | Required; not fully implemented |
| UX-04 | Expense Category does not open options | Replace free-text-only field with selectable searchable categories; offer custom category creation and preserve legacy category text | Requested; design preview only |
| UX-05 | Name and mobile should come from phone contacts | Explicit contact selection, search, choose a number if multiple; manual name/number fallback and optional association | Requested; design preview only |
| UX-06 | Income and Expense may belong to a contact | Save selected contact reference and name/phone snapshot on the transaction; later phone-book changes must not rewrite old transaction details | Requested; design preview only |
| UX-07 | WhatsApp should also use selected contacts | Populate recipient via contact selection or saved entry; user reviews destination and message, opts in and confirms Send in WhatsApp | Requested; design preview only |
| UX-08 | Platform should be more attractive | Refine visual hierarchy, spacing, typography, contact card, category picker and save feedback; retain optional Light/Dark themes | Design review in progress |
| UX-09 | Inline clickable preview did not load on the user's device | Provide directly viewable mobile-sized images for review; static previews are not working app features | Static fallback delivered; revised English design being reviewed |
| UX-10 | Keep noting reported deficiencies | Maintain this register as new observations arrive; distinguish requests, drafts, implementation and passing evidence | Active |

## Proposed category catalogue — not final implementation
Expense: Food, Groceries, Travel, Fuel, Rent, Utilities, Phone & Internet, Office Expenses, Salaries, Advertising, Repairs, Medical, Education, Bank Charges, Taxes, Other; plus Add Category.
Income preview: Sales, Service Fees, Commission / Brokerage, Rent, Salary, Refund, Other. Do not mix income and expense classifications or classify an internal transfer as revenue by default.

## Timestamp and migration requirements
- Persist the save timestamp atomically with the amount entry; do not generate a success time merely in the UI.
- Preserve created_at on edits and record updated_at separately.
- Keep a transaction/accounting date separate from the actual record-save instant if backdated entries are supported.
- Compute the displayed weekday from the timestamp rather than independently storing a possibly inconsistent weekday.
- Offline timestamps come from the device clock; do not represent them as verified server audit timestamps.
- Unknown historic times remain unknown. Never populate them with the current time during migration.
- Test schema upgrades without deleting or reassigning existing balances and entries.

## Review / acceptance
- Show English UI by default, with Hindi explicitly optional.
- Review selectable categories, selected contact/name/number, multiple-number choice, manual fallback, save feedback and readable IST date/weekday/time.
- Confirm immutable transaction contact snapshots and save timestamps through database tests, not just mockups.
- Verify duplicate-tap handling, failed-save behavior, editing after save, old database migration and app relaunch.
- No new APK until the user explicitly asks, even after design approval.
