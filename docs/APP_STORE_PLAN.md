# Duit — Native App Store Plan (superseded)

> **Superseded:** the project direction is now a full native **SwiftUI + SwiftData** rewrite, not a Capacitor wrapper around the web app. See [`docs/IOS_NATIVE_PLAN.md`](./IOS_NATIVE_PLAN.md) and [`/CLAUDE.md`](../CLAUDE.md) for the current plan. §6 below (Apple Developer Program, TestFlight, App Store Connect checklist) is still accurate and is referenced from the current plan — only the "wrap the web app" approach in the rest of this doc is no longer the plan.

| | |
|---|---|
| **Status** | Superseded — kept for history, see banner above |
| **Scope** | Ship the existing Duit codebase as a real App Store app, phased: you → friends (TestFlight) → public |
| **Backend** | None to build. CloudKit (Apple's) replaces Supabase for the native app. |
| **Companion to** | [`docs/PRD.md`](./PRD.md) — this doc only covers what changes to go native |

This assumes the starting point is exactly what's in this repo today: a React 19 + TypeScript + Vite PWA, Dexie/IndexedDB as the local source of truth, optional Supabase sync, WebAuthn+PIN lock, deployed to Vercel. Nothing about that gets thrown away — it gets **wrapped**, not rewritten.

---

## 1. Does this need a backend?

**No.** That's the short answer to your question, and it's a direct consequence of choosing iCloud over a hosted service:

- **CloudKit** (Apple's private-per-user database) becomes the sync backend for the native app. It's free, has no server for you to run or pay for, and it's *automatically* scoped to whichever iCloud account is signed in on the device — so "auth" is just "the user is signed into iCloud," which iOS already guarantees. There's no signup form, no password, no email confirmation, nothing to lose.
- Compare that to the current Supabase path, which needs a project, a schema, RLS policies, and a password the user has to remember. That's fine for one technical user (you, today) but doesn't survive "anyone can download it."
- Since you don't want a 3rd-party integration for the App Store build, the recommendation is: **drop Supabase from the native app entirely**, and decide separately whether the web PWA keeps it (see [§8](#8-open-decisions-yours-to-make)).

This also happens to be the *strongest possible privacy story* for App Review and for a public listing: "your data never touches our servers — it stays on your device and, if you turn it on, in your own iCloud" is something you can put in the App Store description verbatim, and it lets you answer the App Privacy questionnaire with **"Data Not Collected."** That's rare for a finance app and worth using as a selling point.

## 2. Recommended path: wrap with Capacitor, don't rewrite

| Option | Verdict |
|---|---|
| **Capacitor** (wraps the existing web build in a native shell) | **Recommended.** Reuses ~100% of `src/` as-is — every page, component, the whole `domain/` layer, Dexie, Tailwind UI. Gets you to a real `.ipa` in days, not months. Native plugins give you real Face ID, camera (for the receipt-photo roadmap item), and push notifications later. |
| **PWABuilder** | Faster to try, but its iOS output is a thinner, less-maintained wrapper — weaker native plugin story, less control over entitlements like CloudKit. Not worth it given Capacitor is barely more setup. |
| **Full native rewrite (SwiftUI)** | Best long-term native feel, but throws away a finished, tested, working app and rebuilds every screen from scratch. Not justified — nothing about this app needs UIKit/SwiftUI-only capabilities except CloudKit and biometrics, and both are reachable from a wrapped app via small native plugins. |

Capacitor wins because the app is already architected the right way for it: `domain/` is pure functions with no DOM dependency, `db/` (Dexie) works unmodified inside a `WKWebView`, and the sync layer already merges on a transport-agnostic row shape (see next section) — so swapping the transport doesn't touch the merge logic at all.

## 3. System architecture

```
                     Shared, unchanged
        ┌───────────────────────────────────────────┐
        │  React 19 + TS UI  (pages/, features/)     │
        │  domain/  — pure logic, unit-tested         │
        │  db/  — Dexie (IndexedDB), source of truth  │
        │  sync/merge.ts  — LWW merge over RemoteRow  │
        └───────────────────────────────────────────┘
                    ▲                        ▲
                    │                        │
        ┌───────────┴──────────┐  ┌──────────┴────────────┐
        │   Web build (Vercel)  │  │  Native build (Xcode)  │
        │   vite build → dist/  │  │  Capacitor → ios/       │
        │                        │  │                          │
        │  Service worker (PWA)  │  │  No service worker       │
        │  WebAuthn Face ID       │  │  Native Face ID/Touch ID │
        │  Supabase sync (BYO,    │  │  (LocalAuthentication     │
        │   optional, unchanged)  │  │   via Capacitor plugin)   │
        │                        │  │  CloudKit sync (new,      │
        │                        │  │   private DB, per-iCloud- │
        │                        │  │   account, no server)     │
        └────────────────────────┘  └──────────────────────────┘
                                              │
                                     ┌────────┴─────────┐
                                     │  Apple CloudKit    │
                                     │  (user's own iCloud,│
                                     │   free, no BE code) │
                                     └────────────────────┘
```

Key point: `src/sync/merge.ts` already works against a transport-agnostic `RemoteRow` shape (`{ tbl, id, data, updated_at, deleted, server_updated_at }`) — `collectDirty`, `markPushed`, `mergeRemote` don't know or care that Supabase is on the other end. Only `sync/client.ts` (the Supabase SDK) and `sync/engine.ts`'s `push`/`pull` functions are Supabase-specific. That means adding CloudKit is a **new provider next to the existing one**, not a rewrite of the sync engine.

## 4. What changes in the codebase

| Area | Change |
|---|---|
| **New dependency** | `@capacitor/core`, `@capacitor/cli`, `@capacitor/ios`, plus `@capacitor/assets` for icon/splash generation from the existing `public/` assets. |
| **New: `capacitor.config.ts`** | App ID (reverse-DNS, e.g. `id.duit.app` — pick one that matches your Apple Developer account), web dir `dist`. |
| **New: `ios/` platform folder** | Generated by `npx cap add ios`; an Xcode project that loads `dist/` locally. |
| **`src/pwa.ts` / service worker** | Skip registering the service worker when `Capacitor.isNativePlatform()` — native builds don't need it and it can conflict with the local Capacitor webview server. |
| **`src/security/lock.ts`** | Add a native path: on native, use a small Capacitor biometric plugin (real `LocalAuthentication`/Face ID) instead of WebAuthn; keep WebAuthn for the web build. Same `LockSettings` interface, so `LockProvider.tsx` and `PinPad.tsx` don't change. |
| **New: `src/sync/cloudkit.ts`** + a small native Swift plugin | Implements `push(rows)` / `pull(since)` against CloudKit's private database, returning the same `RemoteRow[]` shape Supabase's `pull()` returns today. `sync/engine.ts` picks this provider on native instead of `sync/client.ts`. |
| **`SyncPage.tsx` / Settings** | On native: replace the email/password + "paste your Supabase URL" UI with a single **"iCloud Sync" toggle** (on/off) + last-synced status — closer to how Notes/Reminders present it, and there's no account to create. |
| **App icons/splash** | Regenerate via `@capacitor/assets` from the existing `public/pwa-512x512.png` — the iOS icon set (multiple sizes, no transparency, no rounded corners baked in) has stricter rules than the PWA manifest. |
| **New: privacy policy page** | A static `/privacy` route or page, hosted on the Vercel deployment you already have — required by App Store Connect even though you collect nothing server-side. |

Everything else — every page, every chart, the budgets/recurring/insights logic, the PIN, the CSV/JSON backup — ships unchanged.

## 5. Product requirements — what's new vs. the current PRD

The [existing PRD](./PRD.md) explicitly lists "App Store distribution" as a v1 non-goal and assumes email+password auth. This plan supersedes both for the native app:

| # | Requirement | Notes |
|---|---|---|
| N1 | App installs from TestFlight, later the App Store, with no account creation required | CloudKit uses the device's existing iCloud session |
| N2 | If iCloud is unavailable (signed out, iCloud Drive off), the app still works fully offline | Same principle as today's "works fully without an account" — just extend it to native |
| N3 | Sync toggle is a single switch, not a sign-in form | See §4 |
| N4 | Face ID uses native biometrics, not WebAuthn, on native builds | More reliable inside a `WKWebView` than a resident-key WebAuthn credential |
| N5 | A visible, linkable privacy policy | Apple requires the URL in App Store Connect regardless of what you collect |
| N6 | An in-app way to erase synced iCloud data, not just local data | Extends the existing "erase this device" (`DataPage.tsx`) to also clear the CloudKit zone — this is close to Apple's account-deletion expectation even though there's no "account" |
| N7 | App icon set + launch screens meet Apple's asset rules | Different rules than the PWA manifest icons already in `public/` |

## 6. Apple-specific requirements & gotchas

- **Apple Developer Program**: $99/year, required before you can do *anything* here — TestFlight included. Enroll as an individual unless you specifically need an org account (which needs a D-U-N-S number and takes longer).
- **You need a Mac.** Building, signing, and archiving an iOS app requires Xcode, which only runs on macOS. This session runs on Linux, so I can do all the code-level Capacitor work in this repo (§9), but the actual `ios/` build, signing, and TestFlight upload has to happen on your Mac — or a cloud Mac CI (Codemagic, Bitrise, or a GitHub Actions `macos-latest` runner running `xcodebuild`/`fastlane`) if you don't own one.
- **CloudKit container setup**: enabled per-app in the Apple Developer portal (Certificates, Identifiers & Profiles → your App ID → iCloud capability → CloudKit), then added as an entitlement in Xcode. One-time setup.
- **TestFlight tiers**:
  - *Internal testers* (up to 100) — must be members of your App Store Connect team, builds are available instantly, no review. Fine for just you.
  - *External testers* (up to 10,000) — this is what you need for friends who aren't on your team. First build needs a lightweight "Beta App Review" (usually under 24h); after that, new builds go out instantly.
- **Public submission checklist** (App Store Connect): app name, subtitle, description, keywords, category (Finance), screenshots per required device size, age rating questionnaire, support URL, **privacy policy URL**, App Privacy "data collection" declaration (→ "Data Not Collected," per §1), pricing (Free is the obvious default — no backend cost to recoup), and export-compliance answers (you'll answer "no" to custom encryption beyond what's exempt — HTTPS + the local PBKDF2 PIN hash both qualify for the standard exemption).
- **Review speed advantage**: because there's no login screen, an App Review tester can open the app and use every feature immediately — this avoids one of the most common rejection reasons (reviewers can't get past a sign-in wall). Give them one line in the App Review notes explaining the app works fully offline/local and CloudKit sync is optional.
- **Build/version workflow going forward**: bump `version`/`build number`, `npm run build && npx cap sync ios`, archive in Xcode, upload. TestFlight builds expire after 90 days if you're still in beta.

## 7. Roadmap — phased plan to "usable on the App Store"

```
Phase 0  Prep                      Phase 1  Native wrapper           Phase 2  Friends (TestFlight)      Phase 3  Public
─────────────────────              ─────────────────────             ─────────────────────────          ─────────────────────
□ Apple Developer Program           □ Add Capacitor + ios/ platform   □ Archive + upload build            □ Fill App Store Connect
  enrollment ($99/yr)               □ Icons/splash via                □ Add yourself as internal            metadata + screenshots
□ Confirm bundle ID                   @capacitor/assets                 tester → install today             □ Privacy policy live
  (e.g. id.duit.app)                □ Skip service worker on native   □ Add external testers               □ Submit for review
□ Access to a Mac (own/             □ Native Face ID plugin            (friends' Apple IDs)                 (~24-48h typical)
  cloud CI) for builds              □ CloudKit entitlement + Swift    □ Beta App Review (one-time,         □ Fix any rejection
                                       plugin (push/pull)                first build only)                   feedback
                                     □ New CloudKitSyncProvider        □ Iterate on feedback,               □ Release
                                       wired into sync/engine.ts         ship new builds as needed          □ (later) phased rollout,
                                     □ SyncPage → "iCloud Sync"        □ No public visibility yet             crash monitoring,
                                       toggle, remove Supabase UI                                             roadmap items (savings
                                     □ Privacy policy page                                                   goals, receipt photos
                                                                                                              via native Camera,
                                                                                                              APNs bill reminders)
```

Realistic pacing if you're doing this solo alongside other things: Phase 0–1 is the bulk of the engineering (roughly a week of focused work, most of it doable without a Mac — see §9); Phase 2 is same-day once you have a Mac to archive a build; Phase 3's bottleneck is Apple's review queue, not your work.

## 8. Open decisions (yours to make)

These don't block starting Phase 1, but you'll hit them soon:

1. **Does the web PWA keep Supabase sync?** Recommendation: yes, leave it exactly as-is for the web build (it's already built, tested, and documented) — it just becomes irrelevant to the native app, which uses CloudKit instead. Only revisit this if maintaining two sync backends starts to feel like a burden; the simplification path is deleting Supabase everywhere and making the web build local-only too.
2. **Bundle ID / app name for the App Store listing.** "Duit" as a name is fine; you'll need a reverse-DNS bundle identifier registered to your Apple Developer account.
3. **Pricing.** Free is the natural default given there's no backend cost — but it's your call, and it's a 30-second setting in App Store Connect whenever you decide.
4. **How far "public" goes.** Nothing above requires you to actually flip the listing public — Phases 0–2 get you a fully working app on your and your friends' phones via TestFlight, and you can sit there indefinitely before deciding to submit for full review.

## 9. What can happen right now vs. what needs a Mac

This session runs on Linux, so I can't run Xcode, CocoaPods, or `xcodebuild` here. What I *can* do in this repo right now, if you want to start:

- Add Capacitor as a dependency and generate `capacitor.config.ts` + the `ios/` project skeleton (the CLI can scaffold the Xcode project structure without macOS — you'd open and build it later on your Mac).
- Wire up platform detection (`Capacitor.isNativePlatform()`) to skip the service worker on native.
- Write the native biometric plugin integration points and the `CloudKitSyncProvider` abstraction/TypeScript side (the Swift half needs to be written too, and can be done here as source files — compiling/testing it still needs Xcode).
- Update `SyncPage.tsx` for the native iCloud toggle UI.
- Add the privacy policy page/route.
- Regenerate icon/splash assets.

What has to happen on your Mac (or a cloud Mac CI): opening `ios/` in Xcode, setting your Team/signing, enabling the CloudKit capability, building, archiving, and uploading to TestFlight/App Store Connect.

Say the word and I'll start on Phase 1 in this repo.
