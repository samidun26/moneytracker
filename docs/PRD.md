# Duit — Personal Money Tracker · PRD v1

| | |
|---|---|
| **Status** | v1 in build |
| **Owner** | @samidun26 |
| **Platforms** | iOS (Home Screen PWA) · any modern browser |
| **Last updated** | 2026-09-24 |

---

## 1. Problem

Tracking day-to-day money in IDR is scattered across bank apps, e-wallets (GoPay, OVO, Dana, ShopeePay) and cash. None of them give a single picture of *where the money went this month* or *whether I'm on budget*. Spreadsheets work on a laptop but are painful to update on a phone right after paying for something — so entries get skipped and the data rots.

## 2. Goals & non-goals

**Goals**

1. **Log a transaction in under 5 seconds** from the iPhone Home Screen, online or offline.
2. **One net-worth number** across every wallet, bank and card, always current.
3. **Know if I'm on budget** at a glance, before the month is over.
4. **Never lose data**: device-first storage, background cloud sync, and exportable backups.
5. **Same data on iPhone and laptop** without doing anything manually.

**Non-goals (v1)**

- Bank/e-wallet API integrations or automatic import (no reliable open-banking API in ID for personal use).
- Multi-user / shared household budgets.
- Multi-currency. IDR only, integer rupiah (no decimals).
- App Store distribution.
- Investment/portfolio tracking.

## 3. User

Single user (the owner), iPhone-first, occasionally on a laptop. Pays with a mix of cash, debit, QRIS through e-wallets, and a credit card. Gets a monthly salary and has fixed monthly bills and subscriptions.

**Jobs to be done**

- *When I just paid for something*, I want to record it before I forget, so my numbers stay true.
- *When I'm deciding whether to buy something*, I want to see how much budget is left, so I don't overspend.
- *At the end of the month*, I want to see where my money went, so I can adjust next month.
- *When a bill is due*, I want it logged (or at least flagged) automatically, so I don't have to remember.

## 4. Key product decisions

| Decision | Choice | Why |
|---|---|---|
| Delivery | **PWA** added to Home Screen | Full-screen, offline, no Apple Developer fee or 7-day re-signing; one codebase for iOS and web. |
| Data | **Offline-first** (IndexedDB) + **Supabase sync** | Instant saves with no spinner; works in a lift or on the MRT; the cloud copy doubles as backup. |
| Sync model | Record-level **last-write-wins** with soft deletes | Single user across 2–3 devices. Conflicts are rare and LWW is predictable. |
| Auth | Email + password (Supabase) | Magic links open in Safari, not the Home Screen app, because iOS isolates their storage. Passwords avoid that trap. |
| Currency | **IDR** only, stored as integer rupiah | No float rounding bugs; formatting follows `id-ID` (Rp 150.000). |
| Language | English UI | Owner preference. Numbers and dates still use Indonesian conventions. |
| App lock | **Face ID** (device passkey via WebAuthn) + 6-digit **PIN** fallback | A privacy screen for an unlocked phone; biometric keeps it frictionless. |
| Visual language | **iOS-native** | Large titles, grouped lists, bottom tab bar, system font, automatic light/dark. Feels like a built-in app. |
| Hosting | Vercel | Free, HTTPS by default (required for service workers and WebAuthn), Git-based deploys. |

## 5. Scope — v1

### 5.1 Core: transactions
- Add **expense**, **income**, **transfer** from a single sheet reachable from every screen (center `+` tab).
- Custom numeric keypad with a **`000` key** (IDR amounts are mostly thousands).
- Fields: amount, category (expense/income), account (from/to for transfers), date (defaults today; quick "Yesterday"), note.
- Edit and delete any transaction.
- **Activity** list grouped by day with daily totals, full-text search (note, category, account, amount) and type filters.

**Acceptance**: from app launch to a saved expense takes ≤ 4 taps plus the amount digits: `+` → digits → category → Save.

### 5.2 Accounts & transfers
- Account types: Cash, Bank, E-wallet, Credit card, Savings.
- Opening balance (can be negative for credit cards); balance = opening + income − expense ± transfers.
- **Net worth** = sum of all non-archived accounts.
- Account detail shows its own transaction history.
- Transfers move money between accounts and are excluded from income/expense totals.

### 5.3 Monthly budgets
- A monthly limit per expense category, plus an optional **overall** monthly budget.
- Progress bars with state colors: on track (< 80 %), warning (80–100 %), over (> 100 %).
- "Left to spend per day" = remaining ÷ days left in month.

### 5.4 Insights
- Month switcher.
- Income, expense, net, savings rate.
- Spending by category (donut and ranked list with share and change vs last month).
- Six-month income vs expense trend.
- Daily average and largest expense.

### 5.5 Recurring & subscriptions
- Rules: amount, type, category, account, frequency (daily / weekly / monthly / yearly, with interval), start date, optional end date.
- **Auto-post** mode logs occurrences automatically when the app opens. **Remind** mode lists them as "Due" with *Mark paid* / *Skip*.
- Upcoming bills for the next 7 days appear on Home.
- Deterministic IDs per occurrence, so two devices never double-post.

### 5.6 Settings
- Categories: add, edit, reorder, delete (emoji + color).
- Sync: connect Supabase, sign in/out, last sync, pending changes, *Sync now*.
- Security: App lock on/off, Face ID, change PIN, auto-lock delay.
- Data: export CSV (transactions), export/import full JSON backup, erase device data.
- Appearance: System / Light / Dark.

## 6. UX principles

1. **Thumb-first.** Primary actions sit in the bottom third; the keypad and Save are reachable one-handed.
2. **Zero spinners.** Every write is local and instant; sync is invisible and shows its state only in Settings.
3. **Native idioms.** Large titles, inset grouped lists, bottom sheets, segmented controls. Respect safe areas and the home indicator.
4. **Honest numbers.** Red only means overspending or debt. Income is green; expenses are neutral text, because most rows are expenses and a wall of red is noise.
5. **Desktop is a bonus, not an afterthought.** At ≥ 768 px the tab bar becomes a sidebar and content centers at a readable width.

## 7. Architecture (summary)

```
React 19 + TypeScript + Vite · Tailwind CSS v4 · Lucide icons
├── db/        Dexie (IndexedDB) — source of truth on device
├── domain/    pure functions: balances, budgets, recurring, insights (unit-tested)
├── sync/      push (RPC with server-side LWW guard) / pull (by server timestamp cursor)
├── security/  WebAuthn platform authenticator + PBKDF2 PIN
└── pages/, components/  UI only; read data via live queries
Service worker (Workbox) precaches the app shell → fully offline.
Supabase: one `records` table (jsonb payload per row) + RLS per user.
```

## 8. Success metrics (personal)

- ≥ 90 % of spending logged (compare to bank statements monthly).
- Median entry time < 5 s.
- Budgets reviewed at least weekly.
- Zero data-loss incidents.

## 9. Risks & mitigations

| Risk | Mitigation |
|---|---|
| iOS evicts web storage | Home Screen apps are exempt from Safari's 7-day storage cap; we also request `navigator.storage.persist()`. Cloud sync and JSON export are the backstop. |
| Clock skew between devices breaks sync | Pull uses a **server-assigned** timestamp cursor with an overlap window; merge is idempotent. |
| Face ID not available (older iOS, desktop) | PIN always works; the Face ID toggle only appears when the platform supports it. |
| App lock mistaken for encryption | Documented clearly: it's a privacy screen. Data at rest relies on iOS device encryption. |

## 10. Roadmap (post-v1)

- v1.1 — Savings goals, receipt photo attachments, CSV import from bank statements.
- v1.2 — Bill reminders via Web Push (iOS 16.4+), split transactions, tags.
- v2 — Shared household budget, multi-currency for travel.
