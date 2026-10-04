# Duit — Native iOS Plan

| | |
|---|---|
| **Status** | The native app now covers **the whole retro "Duit OS" prototype** (§9b): five-tab desk, Today (battery, To do, Recent), Activity (wallets, search, filters), Insights (Month, Prices, Habits, Worth it), Settings, Balance Check, Payday boot + Split. Everything **compiles and `DuitTests` pass in CI** (§9); the UI itself has not been seen on a device by the author (this container can't render SwiftUI) — the first real check is yours, on your iPhone (§9b "Updating your phone") |
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

## 9a. Retro "Duit OS" theme (applied to the existing two screens)

Decision (yours, 2026-10-04): the native app should look like the retro prototype (`design/prototype/`, [duit-os-prototype.vercel.app](https://duit-os-prototype.vercel.app)), not the web app's iOS-style look. Implemented as a theme layer plus a restyle of Add Transaction and Activity — **no logic or database changes**.

| Piece | Where | Notes |
|---|---|---|
| Design tokens | `Resources/DuitTheme.swift` | Day/night colors ported value-for-value from the prototype CSS; follows the system light/dark setting; candy palette only. All text/background pairs pass WCAG AA (≥ 4.5:1) in both modes. |
| Fonts | `Resources/Fonts/` + `Resources/DuitFonts.swift` | Silkscreen (titles/buttons), VT323 (LCD amount, keys), IBM Plex Mono (body) — all SIL OFL 1.1, license texts bundled beside them. Registered at launch via CoreText; `ThemeTests` fails if a name doesn't resolve (otherwise iOS silently falls back to the system font). Sizes scale with Dynamic Type. |
| Pixel icons | `Resources/PixelIconData.swift` (generated) | From the prototype's `ICONS`; regenerate with `python3 ios/Tools/gen_pixel_icons.py`. Categories keep storing an emoji; `CategoryPixelIcon` maps it to a pixel icon at draw time and falls back to the emoji for unmapped ones. |
| Components | `Components/RetroChrome.swift`, `RetroControls.swift`, `PixelIcon.swift`, `IconBadge.swift`, `Keypad.swift` | Desk, app bar + palette stripe, windows with title bars and hard shadows, bevel buttons, folder tabs, sunken field, tiles, keypad. |

**Done later:** the Today screen, the other four taskbar tabs and palette / day-night switching all landed afterwards — see §9b.
**Known gaps:** the date picker is still the system control; tile colors for `teal`/`cyan` have no prototype equivalent and were chosen by eye; `Entertainment` uses the prototype's star icon (its "Fun & Hobbies"); the look hasn't been seen on a device by the author — this container can't render SwiftUI.

## 9b. The full prototype, natively (decided 2026-10-04)

Decision (yours): "do all, make it similar to the one I've created at first" — the native app should have every feature of `design/prototype/Main.dc.html`, not just its look. This **overrides** §3's "explicitly later" list for budgets, recurring bills, export and the lock; everything below was built in vertical slices, each one compiled and tested in CI before the next.

### Feature map

| Prototype | Native | Where |
|---|---|---|
| Five-tab taskbar, app bar with the battery | `RetroTaskbar`, `RetroAppBar` | `Components/RetroNav.swift`, `App/AppShell.swift` |
| **Today** — Tanggal Tua battery | `TanggalTuaWindow` (needs "spending money" in Settings) | `Features/Today/TodayView.swift`, `Services/PayCycle.swift` |
| ~~Today — Duit Terminal~~ | **Removed** at your request (2026-10-04) along with the slang parser, question engine and their tests; last present at commit `97d8e12` if you ever want it back | — |
| Today — To do (bills Paid/Skip, "worth it?", balance nudge), Recent | `TodoWindow`, `RecentWindow` | `Features/Today/`, `App/Ledger.swift` |
| New / Edit transaction (3 types, LCD, suggestions, Undo) | `AddTransactionView` | `Features/Transactions/` |
| **Activity** — wallets, search, All / Out / In | `ActivityView`, `ActivitySearch` | `Features/Transactions/`, `Services/` |
| Balance Check | `BalanceCheckView`, `BalanceCheck` | `Features/Wallets/`, `Services/` |
| **Insights** — Month (units, budgets, where it went, 6 months) | `InsightsView`, `TrendChart`, `Insights`, `BudgetLines` | `Features/Insights/`, `Services/` |
| Insights — Prices, Habit Time Machine, Worth-it report | `PriceTracker`, `HabitFinder`, `WorthIt` | `Services/PricesAndHabits.swift` |
| **Settings** — look, payday, security, sync & data | `SettingsView` | `Features/Settings/` |
| Payday boot screen + Payday Split | `PaydayBootView`, `PaydaySplitView`, `PaydayWriter` | `Features/Payday/`, `Services/` |
| Stamps, toast with Undo, retro alert | `StampView`, `ToastView`, `.retroAlert` | `Components/RetroExtras.swift` |

The prototype ran on sample data; the native app reads **your** transactions for everything. The calculation rules are ports of `src/domain/*.ts` and the prototype's own JS, with the prototype's sample numbers as test expectations (e.g. Rp 478.500 left → 4 %, Rp 68.357 a day, "+33 %" mie ayam, 95.376 an hour). The Terminal's own sample numbers went away with it..

### Architecture, kept simple

- Screens read one value-type `Ledger` snapshot built in `RootView` from the SwiftData `@Query` results. All rules live in pure `Services/` functions over plain `Entry` values, so they're unit-tested without a database; writes go through `EntryWriter`, `RecurringPoster` and `PaydayWriter`.
- New fields on `Transaction` are optional (SwiftData migrates them automatically), and `Store.makeContainer` never deletes an unreadable store: it moves it aside as `default.store.backup-<time>` and tells you once.
- No backend, no custom account. The optional lock is Face ID with the iPhone's own passcode as the backup (§9c).

### Product decisions I made — please confirm or override

1. **Setup lives in Settings.** The prototype had sample wallets, budgets and bills. A real app needs a way to create them, so Settings has: *Spending money* (the overall budget that powers the battery), *Monthly salary*, **Wallets** (add / rename / type / starting balance / archive; delete only if it has no history), **Category budgets**, **Bills & subscriptions** and **Payday split buckets**. A fresh install starts with three wallets (Cash, Bank, E-wallet) and four buckets (Rent, Savings, Family, Bills & subscriptions) with Rp 0.
2. **Payday day** can be any day 1–31 (prototype: 1st, 25th, 28th presets + "Another day…").
3. **Payday Split** logs your salary as income once per pay period (skipped if you already logged "Salary" since payday), remembers each bucket's amount for next month, and makes the leftover your spending money. "Later" changes nothing.
4. **"Mie ayam" unit** uses your latest "mie ayam" price; if you've never logged one it assumes Rp 20.000 and says so. **"Work hrs"** needs a salary (salary ÷ 173) and otherwise stays in rupiah.
5. **Lock** engages as soon as the app goes to the background (no grace period) and closes any open sheet so nothing sits above the lock screen.
6. **Reset all data** erases transactions, wallets, budgets, bills and buckets and restores the starting wallets, categories and buckets. Look settings and the lock stay.
7. **Deliberately not built:** category add/edit/delete (the 22 defaults are fixed), JSON backup/restore (CSV export/import came later, §9d), account detail pages, first-run onboarding, iCloud sync (the "Connect…" button says so), widgets and notifications. All are in the web app or `§3 later`; each is its own decision.

### Known gaps and caveats

- **Not seen on a device.** CI proves it compiles and the logic is right; layout, fonts, motion, Face ID and sharing are unverified until you run it.
- The system **date picker** (bill start date) and **share sheet** (Export CSV) are native, not retro-styled.
- Categories whose emoji has no pixel icon show the emoji; `teal` / `cyan` tile colors are my own picks.
- A fresh `xcodegen generate` resets Xcode's signing — re-pick your Team (§ "Updating your phone").
- Data written by the first prototype build (before wallets existed) is migrated by giving it to Cash; that migration was written but never run against a real old store.

### Updating your phone (Mac)

1. In your clone: `git pull` on branch `claude/determined-wright-b7gk90` (or merge PR #4 first).
2. `cd ios && xcodegen generate` — this rewrites `Duit.xcodeproj`, so **Signing & Capabilities → Team** must be picked again.
3. Plug in the iPhone, choose it as the destination, press Run. Your data stays (same bundle ID); delete the app first only if you want a clean start.

## 9c. App icon, widgets, and the Terminal's removal (2026-10-04)

Requested: put the pixel credit-card art in as the icon, remove the Duit Terminal, and add widgets ("current spends" and an "add to log" shortcut that opens the app on a new expense; the kinds were left to me).

**App icon** — `Duit/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, 1024×1024, opaque (iOS adds the rounded corners). The source picture was 565 px, so a plain upscale would have blurred the pixel edges. `ios/Tools/make_app_icon.py` finds the art's pixel grid (about 11.2 px per art pixel), keeps the sprite as square crisp pixels and enlarges the soft pastel background smoothly; re-run it with a higher-resolution original for a sharper result.

**Logo in the app (2026-10-04)** — the app bar, the lock screen and the Payday boot screen used to draw the prototype's pixel "D" with a coin; they now draw the same credit cards as the app icon (`DuitLogo`, data in the generated `Resources/DuitLogoData.swift`). `ios/Tools/make_logo_sprite.py` reads the art-pixel grid straight back out of `AppIcon.png` (so there's no second source picture to keep in sync), drops the soft shadow, and writes both the Swift data and the prototype's `<symbol id="duit-logo">`. The outer black edge is painted in the theme's ink colour so it stays visible on the night-mode bar; black pixels inside the art (the magnetic stripe) stay black. The prototype's `icon-192.png`, `icon-512.png` and `apple-touch-icon.png` were re-made from the same icon. Not redone: the README screenshots (`docs/screenshots/`, still the old "D"), and the old React app's own icons in `public/`.

**Lock (2026-10-04)** — unchanged in principle: Face ID first, the iPhone passcode as the backup, no Duit PIN. `AppLock` uses the `.deviceOwnerAuthentication` policy, which is what puts the passcode in the same system prompt when Face ID isn't recognised, is locked out after too many tries, or isn't set up. What changed: only "this iPhone has no passcode" (`LAError.passcodeNotSet`) now switches the lock off; before, *any* failure of the availability check did, so a momentary system error could silently turn the lock off. The lock screen and Settings say what the backup is, and the prototype's Settings text changed from "6-digit PIN" to the iPhone passcode (the prototype's checkbox is only a mock; a browser can't show the real Face ID or passcode prompt). `AppLockTests` covers the error mapping.

**Widgets** (`ios/DuitWidget/`, a WidgetKit extension; Home Screen and Lock Screen):

| Widget | Sizes | What it does |
|---|---|---|
| **Spending** | small, medium, Lock Screen circular / rectangular / inline | Tanggal Tua battery with "Rp … a day", spent today and this month. Without spending money set it shows this month's total on an LCD. Tap opens Today. The medium one also has a **NEW** button. |
| **Quick add** | small, Lock Screen circular | One big **+**; tap opens Duit on **New expense**. |

How it works, and why it's built this way:

- **The widget never reads your transactions.** The app writes a small `WidgetSnapshot` (today's and this month's spending, battery, palette) into an **App Group** (`group.com.samidun26.duit`) whenever your data changes, and asks WidgetKit to redraw. The SwiftData store stays where it is, so there's no data migration and no risk to what's already on your phone.
- **`duit://add`** is registered as a URL scheme (`duit://today` just opens the app). The app handles it in `AppShell` / `RootView`. If the lock is on, the link waits until you've unlocked, and any sheet that was open is closed first.
- **Privacy:** with "Require Face ID to open" on, widgets show "Locked" instead of amounts (Lock Screen widgets are visible without unlocking the phone).
- **After midnight** a widget shows "today" as zero even if you haven't opened the app, and a new month starts at zero; the battery only updates when the app runs.
- Colors are duplicated in `DuitWidget/WidgetStyle.swift` (the app's `Theme` uses dynamic colors that don't survive into a widget process): keep them in sync. The widget picks day or night from the system, not from the app's Look setting.
- Pure logic (`WidgetSnapshotBuilder`, staleness, `AppRoute`) is unit-tested; the widget views themselves are not (no device here).

**Needs on your Mac:** `git pull`, `cd ios && xcodegen generate`, then in Xcode pick your **Team for both targets, Duit and DuitWidget** (Signing & Capabilities); the App Groups capability is added from the generated entitlements. Add the widgets from the Home Screen's edit mode (+), or the Lock Screen's Customize.
**Risk:** I believe a free "Personal Team" can use App Groups, but I couldn't confirm it from here. If Xcode refuses ("…does not support the App Groups capability"), the widgets can't share data on a free account; tell me and I'll make the Quick add widget work without it.
**Changing the bundle ID later** (Phase 5) means changing the group ID in `project.yml` and `Shared/WidgetSnapshot.swift` too.

## 9d. CSV import and export (2026-10-04)

Requested: "implement CSV import / bank statement, you decide the format, and export so that after an update we can import the app's own export."

**Settings → Sync & data** now has **Export CSV…** and **Import CSV…**. Import opens a preview first (what was understood, how many rows are new / already in Duit / skipped, the first six rows) and only writes when you tap **Add N**. A toast offers **Undo**, which removes exactly the rows that import added.

| File | Where | Notes |
|---|---|---|
| Duit's own export | `Services/CSVExport.swift` | `Date, Type, Amount, Signed amount, Category, Account, To account, Note` (the web app's columns) **plus `ID` and `Worth it`**, so the file is read back exactly. Exports from before this change still import (no ID: matched by content). |
| Reader | `Services/CSVParser.swift`, `CSVImport.swift`, `ImportParsing.swift` | Quotes, line breaks in cells, CRLF, BOM, `, ; tab \|`, UTF-8 / UTF-16 / Windows-1252. |
| Planner | `Services/ImportPlan.swift` | Pure: wallets, duplicates, categories. |
| Writer | `Services/ImportWriter.swift` | The only code that writes imported rows, and removes them for Undo. |
| Preview | `Features/Settings/ImportCSVView.swift` | |

**Bank statements.** The header row is found on its own (within the first 40 rows, so account-name lines above the table are fine) by looking for a date column and money columns, in English or Indonesian (`Tanggal`, `Keterangan`, `Debet`, `Kredit`, `Jumlah`, `Saldo`…). Money is read as either **Debit + Credit columns**, **one Amount column** whose sign, brackets, `DB`/`CR` mark or a **Type column** gives the direction. Numbers read as `1.234.567,89` or `1,234,567.89`; dates as `31/12/2025`, `2025-12-31`, `1 Okt 2025`, with or without a time (day-first unless the file proves month-first). If a file's amounts carry *no* direction at all, Duit assumes positive = money in and shows a **Money in / Money out** switch in the preview.

**Decisions I made, please confirm or override:**

1. **Duplicates.** A Duit export is matched by ID, then by the whole row (day, type, amount, wallet, title). A bank statement is matched by **day + amount + wallet only**, because the bank's wording never equals what you typed ("QRIS KOPI KENANGAN" vs "Kopi"); this stops a statement from doubling what you already logged by hand. Rows are counted, not just checked: two real Rp 20.000 lunches stay two. The cost: a genuinely new bank row with the same day, amount and wallet as a manual entry is skipped as "already in Duit". A bank date that differs by a day from your manual entry is not matched.
2. **Categories for statements** come from titles you've used before (the same title, or a statement line that contains one of your titles of 4+ letters); everything else is **Other**. There is no built-in merchant keyword list.
3. **Wallets.** Statement rows go to the wallet you pick in the preview. A Duit export carries wallet names; a name that doesn't exist yet is **created** (starting balance Rp 0, a type guessed from the name: GoPay → e-wallet, Visa → credit card, otherwise bank).
4. **The CSV holds transactions only.** Wallets' starting balances, budgets, bills, Payday split buckets and settings are not in it, so after a reinstall balances can differ from before until you re-enter starting balances (Settings → Wallets, or Balance Check). A full backup (JSON, as the web app has) is the real fix and is its own decision; it is still not built.
5. **Limits.** 5 MB per file; `.csv`/`.txt` only (not `.xls`/`.xlsx`/PDF); a date without a year (`01/10`) is skipped and reported; transfers between your own wallets can't be recognised in a bank statement (they import as spending or income).

**Not verified:** this container has no Swift toolchain, so CI is the compiler and the tests' only runner. The statement layouts in `CSVImportTests` are typical shapes written for the tests, **not real bank files**. The first real check is importing your own bank's CSV on your iPhone; tell me which bank and what goes wrong and I'll add that layout to the tests.

## 9e. Profiles: "Mine", "Us" (2026-10-04)

Requested: a separate profile for the user's own money and another for the user and their partner (shared money, expenses…) "that doesn't affect mine". Decisions (yours): **same iPhone** (switch profiles), **fully separate**, **everything per profile**, **no per-profile lock** (the app lock covers all).

**How it works.** Every profile is its **own database file** (`ProfileStores` keeps one `ModelContainer` per profile; the screens only ever get the open profile's). So nothing in one profile can show up in, or change, another by construction, and Today, Activity, Insights, budgets, bills, Payday Split, the battery, CSV import/export and Reset all work exactly as before, scoped to the open profile, with no change to the existing models, `Ledger` or calculations. Your existing data **is** the first profile, "Mine": it keeps using `default.store` and the standard settings, so nothing is moved, copied or migrated.

| Piece | Where |
|---|---|
| The list of profiles, rules (unique names, max 6, the open and first can't be deleted), saved as JSON in UserDefaults | `Services/Profiles.swift` (`ProfileRegistry`) |
| One database per profile, switching, deleting | `Services/ProfileStores.swift`, `Services/Store.swift` (`makeContainer(storeName:)`, `deleteFiles`) |
| Per-profile settings: payday day, salary, the Payday Split done, the wallet used last | `Prefs.profile` (the open profile's own UserDefaults; the first profile uses `.standard`) |
| App-bar chip (color + name, always shown), switcher, add / rename / recolor / delete | `Features/Profiles/ProfilesView.swift`, `RetroAppBar`, Settings → Profiles |
| Switching rebuilds the screens (the same trick as changing palette) and keeps the lock state, so it never asks for Face ID again | `AppShell` |

**Still shared across profiles (device-wide):** look (theme, palette, dots) and the Face ID lock. **Separate per profile:** wallets, transactions, budgets, bills, Payday Split buckets, spending money, salary, payday day.

**Things to know:**

- **Bills post when their profile is open.** Auto-post bills in "Us" are logged (with catch-up for every missed date) the next time you open "Us", not while "Mine" is open.
- **Widgets show the profile you last used.** Their numbers come from the open profile's snapshot; they don't say which profile (not built).
- **Export / Import CSV act on the open profile**; a non-first profile's file is named `duit-<profile>-transactions-<date>.csv`, and the import preview says which profile it goes into. This is also the way to move "Us" to your partner's iPhone by hand today; see below.
- **Delete is permanent** (database files and settings), after a confirmation. The first profile can only be emptied with Reset all data. Reset all data now empties the **open profile only**.
- The profile list is a small JSON in UserDefaults. If it were ever lost, each profile's database file would still be on the phone but unlisted (there's no "find lost profiles" screen).
- **Not built:** a combined "All profiles" overview, copying a transaction between profiles, per-profile lock, "paid by me / partner" on shared spending or a settle-up summary, and **live sharing with a partner's own iPhone** (SwiftData can't share a database between two people; that means CloudKit sharing, its own project and listed as "later" in §3).
- **Not verified on a device:** this container has no Swift toolchain, so CI is the compiler. In particular, opening a second SwiftData store next to the first, and the chip's fit on small iPhones, are untested on real hardware.

## 9. CI builds and unsigned IPAs (no Mac required for a compile check)

`ios/project.yml` (XcodeGen spec) + `.github/workflows/ios.yml` give this repo a Swift compiler it otherwise lacks: on every push touching `ios/**`, a GitHub-hosted macOS runner generates the Xcode project, runs `DuitTests` on an iPhone simulator, and builds an **unsigned** `Duit-unsigned.ipa`, uploaded as a workflow artifact (14-day retention). Compiler errors from the first run are the fastest way to fix the "unverified" code listed in §8.

**First run (2026-10-03, [run 37100925048](https://github.com/samidun26/moneytracker/actions/runs/37100925048)):** both jobs green — the app compiles for a Release device build and for the iOS 26.5 simulator, `DuitTests` passed, and the IPA artifact was produced. The test step prints only failures and the final tally (the full log is written to a file on the runner), so a red run names the assertion that broke.

**Releases:** [`v0.2.0`](https://github.com/samidun26/moneytracker/releases/tag/v0.2.0) (the full prototype, §9b) is the latest public pre-release carrying the unsigned IPA; [`v0.1.0`](https://github.com/samidun26/moneytracker/releases/tag/v0.1.0) is the first slice. To cut another, run the workflow manually (Actions → iOS → Run workflow, or `workflow_dispatch` via API) with `release_tag` set to e.g. `v0.1.1` — it rebuilds, runs the tests, and only publishes if both pass. The tag is created at the commit you run it from; bump `MARKETING_VERSION` in `ios/project.yml` first so the app's version matches. To undo a release, delete the release and its tag on GitHub.

What this does **not** give you:

- **Proof the app behaves correctly.** A green build and passing unit tests don't cover the UI or SwiftData persistence. §8.6 (add an income and an expense, quit, reopen) still has to be done by hand.

- **An installable app.** iOS only runs signed code. The unsigned IPA must be re-signed with a free Apple ID via Sideloadly/AltStore (device-registered, expires after 7 days, max 3 sideloaded apps), or replaced by a signed TestFlight build in Phase 5 (needs the $99/yr Developer Program).
- **Private downloads.** The repo is public, so artifacts are downloadable by any signed-in GitHub user.
- **A final bundle ID.** `com.samidun26.duit` is a placeholder — set the real one before Phase 5.

The generated `Duit.xcodeproj` is gitignored. On a Mac, `brew install xcodegen && cd ios && xcodegen generate` replaces the manual "create project in Xcode" step in §7/§8.4.
