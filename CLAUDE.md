# Duit — Project Guide

Duit is a personal finance / money tracker, mid-pivot from a React PWA prototype
to a **native iOS app** (the actual product). Both live in this repo.

## Repo layout

- `src/`, `public/`, `docs/PRD.md`, etc. — the original React 19 + TS + Vite PWA.
  This is now a **reference implementation only**: the UI/UX/interaction spec and
  a working, unit-tested spec for the domain calculations (see below). It stays
  deployed on Vercel as-is. Don't add new product features to it; small fixes are
  fine if something's broken.
- `ios/` — the native SwiftUI production app. This is where new feature work
  happens going forward.
- `docs/IOS_NATIVE_PLAN.md` — the live roadmap, reconciliation notes, and current
  status for the native rewrite. Read this before starting native work.
- `docs/APP_STORE_PLAN.md` — an earlier plan (Capacitor-wrap approach), superseded
  by the native rewrite decision. Its Apple/App-Store-logistics sections (Developer
  Program, TestFlight, App Store Connect checklist) are still accurate and are
  cross-referenced from the current plan.

## Product philosophy

Build the simplest architecture that can reliably support the product. Avoid
premature backend services, APIs, custom auth, microservices, DI frameworks, or
any abstraction that doesn't solve a requirement that exists today.

## Stack (native app)

- Swift, SwiftUI, SwiftData (local persistence), Swift Charts.
- CloudKit + iCloud for sync — **optional, added only after local CRUD is stable**,
  never a requirement for basic app functionality.
- No custom backend. No Node/Express/REST/GraphQL/Postgres/Mongo/Firebase/Supabase
  server, no custom JWT auth — none of that is justified for a local-first,
  manually-entered personal finance app.
- No login/register/password flow. If CloudKit sync is added later, identity comes
  from the device's existing iCloud session, not a custom account system. The app
  opens straight into the product.

## Using the web app as a spec

`src/domain/*.ts` and `src/lib/money.ts` / `src/lib/dates.ts` are a working,
unit-tested spec for the calculation rules (balances, budget pace, recurring
schedules, insights, IDR formatting) — **port the algorithms to Swift
`Services/`, don't re-derive them from scratch.** `src/pages/` and
`src/features/` are the UI/UX/interaction reference — translate the *design*,
not the code; prefer native SwiftUI idioms over a literal port of DOM/Tailwind
structure.

## Decision priority

1. Correctness 2. Simplicity 3. User experience 4. Maintainability
5. Native iOS conventions 6. Performance 7. Scalability

Scalability is intentionally last — this is a local-first personal app.

## Development strategy

Vertical slices, not screen-by-screen. Don't build every screen before the first
slice (Add Transaction → SwiftData → Transaction History → survives app restart)
works end to end. Don't implement roadmap/"later" features while the MVP slice is
unstable.

## Claude's role here

**Do**: implement SwiftUI/SwiftData, explain unfamiliar Swift concepts, review
architecture and code quality, flag unnecessary complexity and bugs, suggest
justified refactors, write tests, help debug Xcode errors, check work against
`docs/IOS_NATIVE_PLAN.md`.

**Don't**: redesign the architecture without justification, add a backend or a
dependency without explaining why, over-engineer simple features, silently
change product requirements, or build "later" features while the MVP is
unstable.

Before implementing anything: state the requirement, name the affected files,
explain the proposed approach, check for an existing component/service to
reuse, implement the smallest reasonable solution, build, fix errors, test the
affected flow, and report what changed — in that order. The user is the
supervisor of this project: surface decisions and trade-offs rather than
making product calls silently.

## Environment note

This container has no Xcode/Swift toolchain (Linux). Swift source can be
written and organized here, but building, running in Simulator, and
TestFlight/App Store submission require a Mac — see `docs/IOS_NATIVE_PLAN.md`
for the split of what happens here vs. on a Mac.
