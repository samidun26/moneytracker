# Duit — Native iOS Plan

| | |
|---|---|
| **Status** | First vertical slice source-complete (Models, Services, Components, Add Transaction, Transaction History) — waiting on Xcode project creation (your Mac) to actually build and verify any of it |
| **Supersedes** | [`docs/APP_STORE_PLAN.md`](./APP_STORE_PLAN.md)'s Capacitor-wrap approach (its Apple/App-Store logistics sections are still valid, cross-referenced below) |
| **Governing rules** | [`/CLAUDE.md`](../CLAUDE.md) — philosophy, stack, and "rules of engagement" for this project. Read that first; this doc is the roadmap and status. |
| **Supervisor** | You. I propose and explain before implementing; you decide on anything that changes product scope. |

## 1. What changed from the previous plan

The earlier plan (`docs/APP_STORE_PLAN.md`) proposed wrapping the existing React PWA with Capacitor — reuse the web code, add native plugins. That's superseded: the decision now is a **full native rewrite in SwiftUI + SwiftData**. The web app (`src/`) becomes a reference/prototype only — it stays deployed on Vercel as-is, but gets no further product investment. Everything new happens in a new `ios/` folder in this repo.

Two things carry over unchanged, because both plans independently landed on the same answer:

- **No custom backend.** Confirmed again here — see `CLAUDE.md`.
- **No custom auth.** The app opens straight into the product; CloudKit (if/when added) uses the device's iCloud session as identity.

One thing got *more conservative*: the previous plan had CloudKit sync as part of the first native build. The new guide is explicit that CloudKit should only be added **after local CRUD is stable** — sync is now a later phase, not a day-one feature.

## 2. Repo layout going forward

```
moneytracker/
├── src/, public/, docs/PRD.md, ...   ← existing web app, reference-only from now on
├── ios/                                ← NEW: native SwiftUI production app
│   └── Duit/
│       ├── App/                        entry point, app-level config
│       ├── Features/
│       │   ├── Dashboard/
│       │   ├── Transactions/
│       │   ├── Statistics/
│       │   └── Settings/
│       ├── Models/                     SwiftData models (Transaction, Category, …)
│       ├── Services/                   business logic, ported from src/domain/
│       ├── Components/                 reusable SwiftUI views
│       ├── Utilities/
│       └── Resources/                  design tokens, assets
├── CLAUDE.md                           governing rules for this project
└── docs/IOS_NATIVE_PLAN.md             this file
```

## 3. MVP scope

**Primary (build these, in this order):**

1. Dashboard
2. Add transaction
3. Income transaction
4. Expense transaction
5. Transaction history
6. Categories
7. Basic financial statistics
8. Settings

**Explicitly later** (don't build until the above is stable): budgeting, recurring transactions, goals/gamification, advanced analytics, custom themes, widgets, notifications, export/import, CloudKit.

### Open scope question — flagging, not deciding

The current web app treats **multi-account tracking and net worth** (Cash / Bank / E-wallet / Credit card / Savings, with transfers between them) as core — it's goal #2 in `docs/PRD.md`. The new MVP list above has no Account entity at all; transactions are implicitly against a single running balance. Same for **App Lock** (Face ID/PIN) — it's a shipped feature today but isn't in the MVP or "later" list.

My recommendation: keep the true MVP exactly as scoped above (single balance, no lock) to get the vertical slice done fast, then treat **Accounts/net worth** as the very next slice after the MVP is stable (it's cheap to add to the SwiftData schema early and is a real value prop, per the current PRD) — and treat **App Lock** as a Settings-phase add-on once Dashboard/Transactions exist. This is your call to confirm or override.

## 4. Data model — v1 bootstrap

```swift
// Transaction
id: UUID
type: income | expense
amount: Int            // integer rupiah, no decimals — matches the web app's approach
category: Category
note: String?
date: Date
createdAt: Date
updatedAt: Date

// Category
id: UUID
name: String
icon: String
type: income | expense
createdAt: Date

// Budget — only introduced when budgeting enters scope (not MVP)
```

Integer rupiah (no float rounding bugs) carries over from the web app's `src/lib/money.ts` — that's a correctness decision worth keeping, not re-litigating.

## 5. Reusing the web app as a spec

The web app's `domain/` layer is tested and already encodes the exact calculation rules. Port the *algorithm*, not the code:

| Web source (spec) | Ports to (native Service) | Covers |
|---|---|---|
| `src/lib/money.ts` | `CurrencyFormatter` | IDR formatting (`Rp 150.000`), integer-rupiah arithmetic |
| `src/lib/dates.ts` | `DateHelpers` | Month boundaries, "days left in month", relative dates |
| `src/domain/balances.ts` | `BalanceCalculator` | Account/running balance math (once Accounts is in scope) |
| `src/domain/budgets.ts` | `BudgetCalculator` | Budget pace, 80%/100% thresholds (once Budgets is in scope) |
| `src/domain/recurring.ts`, `recurringActions.ts` | `RecurringScheduler` | Deterministic occurrence IDs, auto-post vs remind (later) |
| `src/domain/insights.ts` | `InsightsCalculator` | Category breakdown, month-over-month change, trends |
| `src/domain/backup.ts` | `ImportExportService` | JSON/CSV export shape (later) |

`src/pages/*` and `src/features/*` are the UI/UX/interaction reference for the retro/vintage visual language — translate layout, hierarchy, spacing, and interaction, not JSX/Tailwind structure.

## 6. Roadmap phases

```
Phase 0  Product definition          Phase 1  First vertical slice        Phase 2  Core MVP complete
──────────────────────────           ──────────────────────────           ──────────────────────────
□ Confirm MVP screen list             □ Create Xcode project (your Mac)     □ Dashboard
□ Resolve open scope question          — SwiftUI, SwiftData, bundle id      □ Categories (CRUD)
  (§3) — Accounts, App Lock           □ Transaction + Category models       □ Basic statistics
□ Confirm navigation/flows            □ Add Transaction screen              □ Settings shell
□ Confirm calculation rules            (income + expense)                  □ Physical-device testing
  (reuse §5 table)                    □ Persist via SwiftData
                                       □ Transaction History screen
                                       □ Verify: add → quit → reopen
                                         → transaction still there

Phase 3  Stabilize                    Phase 4  Optional CloudKit           Phase 5  Ship
──────────────────────────           ──────────────────────────           ──────────────────────────
□ Edge cases (§ testing list          □ Only after Phase 3 is solid        □ Apple Developer Program
  below)                              □ CloudKit entitlement + container      ($99/yr) — see
□ Unit tests on Services              □ Sync as a background layer,           docs/APP_STORE_PLAN.md §6
□ Internal dogfooding                   never required for the app to       □ TestFlight: you, then
  (you, on your device)                 function                              friends (external testers)
                                       □ Handle "not signed into              □ App Store Connect metadata,
                                         iCloud" gracefully                    privacy policy, screenshots
                                                                              □ Submit for review → release
```

Testing checklist for Phase 3 (from the governing guide): zero transactions, very large amounts, decimal/currency edge cases, deleting/editing transactions, changing categories, dates crossing months, invalid input, app restart.

**Apple account/logistics stay the same regardless of Capacitor vs. native** — `docs/APP_STORE_PLAN.md` §6 (Developer Program, TestFlight internal vs. external tiers, App Store Connect checklist, export compliance) is still accurate and is what Phase 5 above points to. The only part of that old doc that's no longer the plan is the *how* (Capacitor wrapper) — the *what you need from Apple* didn't change.

## 7. What happens here (this session) vs. on your Mac

This container is Linux — no Xcode, no Swift toolchain, confirmed. Concretely:

- **Here**: write and organize Swift source (Models, Services, Views) following the `ios/Duit/` structure in §2; port calculation logic from `src/domain/`; write unit tests as plain source; keep this plan and `CLAUDE.md` current.
- **On your Mac**: create the actual Xcode project (File → New → Project → iOS App, Interface: SwiftUI, Storage: SwiftData), point it at (or copy in) the `ios/Duit/` source, build, run in Simulator, test on your physical iPhone, archive, and upload to TestFlight/App Store Connect.

Modern Xcode (15+) supports "file system synchronized groups" — if you create the project with its source folder pointed at `ios/Duit/`, files added here just show up in Xcode without manual re-adding. I'll follow that folder shape so this stays low-friction for you.

## 8. Immediate next task

Per the governing guide's own instruction — don't build the whole app, build the first vertical slice:

1. ~~Confirm the open scope question in §3 (Accounts + App Lock: MVP or deferred).~~ Not explicitly confirmed — proceeding on the recommended default (deferred) since it wasn't overridden; still your call to correct.
2. **Done** — `Transaction`, `Category`, `TransactionType`, `CategoryColor` as Swift/SwiftData models in `ios/Duit/Models/`.
3. **Done** — folder scaffold under `ios/Duit/` (`App/`, `Models/`, `Services/`) plus a full `CurrencyFormatter` port (verified by hand against `money.test.ts`'s exact expected strings) and a trimmed `DateHelpers` port (only what Add Transaction/History need — see file header for what's deferred and why). Matching XCTest files are in `ios/DuitTests/`, ported from the web app's own test cases, but **unverified** — this container has no Swift toolchain to actually run them.
4. **Next, on your Mac**: create the Xcode project (File → New → Project → iOS App, Interface: SwiftUI, Storage: SwiftData, name "Duit"), point its source at (or copy in) `ios/Duit/`, and add `ios/DuitTests/` as its test target. Run the unit tests first — that's the fastest way to catch anything that doesn't compile or doesn't match before touching the UI.
5. **Done, unverified** — `ios/Duit/Components/{IconBadge,Keypad}.swift`, `ios/Duit/Features/Transactions/{AddTransactionView,TransactionHistoryView,TransactionRow}.swift`, and `ios/Duit/Services/DefaultCategories.swift` (seeds the same default category list as `src/db/seed.ts` on first launch, since Categories CRUD — MVP item 6 — isn't built yet and Add Transaction needs something to pick from). `DuitApp.swift` now boots straight into Transaction History with a `+` button, matching the current MVP root until Dashboard exists.
6. Verify on your Mac: build, run in Simulator, add an income and an expense, quit the app, reopen — both should still be there. Report back whatever breaks first; SwiftUI/SwiftData errors are much faster to fix from an actual compiler error than from more guessing here.

**Definition of done for this slice**: a user can manually create an income or expense transaction, close the app, reopen it, and still see the transaction. Nothing past that (Dashboard, Statistics, etc.) starts until this is solid.
