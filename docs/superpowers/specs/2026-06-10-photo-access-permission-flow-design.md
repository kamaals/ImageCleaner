# Photo Access Permission Flow — Design

**Date:** 2026-06-10
**Status:** Approved (design); pending spec review
**Scope:** Photos authorization UX for PhotoPrune (iOS 18+, SwiftUI + SwiftData)

## Problem

A TestFlight tester who declines Photos access gets a silent, broken app, and
the app does not appear in **Settings → Privacy & Security → Photos** so there
is no way to recover. Investigation of the current code found three root causes.

### Root causes (evidence)

1. **Silent on refusal.** `ScanStore.runScan()` sets
   `lastError = "Photo library access denied."` on a non-authorized status
   (`ScanStore.swift:114`), but `lastError` is read by **no view** — it is
   referenced only inside `ScanStore.swift`. The denial message is set and
   discarded; the SCANNING animation unwinds to "0 found" with no explanation.

2. **App absent from the Photos settings list.** iOS lists an app under
   Settings → Privacy → Photos only **after** the app has called
   `PHPhotoLibrary.requestAuthorization` at least once (that call writes the
   app's TCC consent record). Today the only request lives at the bottom of the
   scan flow: `tap SCAN → animateToScan() → wait 2.2s (scanKickoffDelay) →
   ScanViewModel.startScan → store.runScan → requestAuthorization`
   (`ScanStore.swift:109-110`). A tester who does not complete that path — or
   whose deferred kickoff Task is cancelled mid-animation — never triggers the
   request, so iOS has no record and the app never appears in the list. The
   usage-description string itself is present and correct
   (`INFOPLIST_KEY_NSPhotoLibraryUsageDescription`), so this is not a missing
   Info.plist issue.

3. **Real authorization status is never synced.** `ScanStore.authorizationStatus`
   is initialized to `.notDetermined` and only ever updated by
   `requestAuthorization()`. The read-only `library.authorizationStatus()`
   exists but is never called. A returning user who previously denied launches
   with a stale `.notDetermined`; the first SCAN calls `requestAuthorization()`,
   which — because iOS does not re-prompt after denial — returns `.denied`
   instantly with **no dialog**, collapsing back into root cause 1.

### iOS constraint

The system permission dialog can be shown only when status is `.notDetermined`.
After `.denied`/`.restricted`, the only recovery is deep-linking to Settings
(`UIApplication.openSettingsURLString`). The fallback UI must branch on the real
status, or a "grant access" button silently no-ops on a denied state.

## Decisions

- **Priming** screen before the first scan (educate, then trigger the system
  dialog) — chosen for higher grant rates and reliable registration in Settings.
- **Limited access is insufficient.** A whole-library cleaner can only see the
  user-picked subset under `.limited`, so limited routes to "grant full access."
- **Full-screen state on home** for the needs-access / denied / limited states.
- **Gate at the home screen**, driven by the real status — not a launch-time
  gate (which would kill the splash→home hero animation and complicate the
  launch-into-saved-results path).
- **Saved-results edge case = option (a):** a returning user with saved results
  but revoked access still opens into the saved results; the gate surfaces when
  they try to scan or delete.

## State model

`PhotoAccessState` (new), mapped from `PHAuthorizationStatus`:

| `PHAuthorizationStatus` | `PhotoAccessState` | Home shows | Primary action |
|---|---|---|---|
| `.authorized` | `granted` | SCAN hero (unchanged) | runs scan |
| `.notDetermined` | `needsPriming` | SCAN hero (hero preserved) | tap SCAN → priming cover → "Allow Access" → system dialog |
| `.limited` | `needsFullAccess` | full-screen permission state | "Open Settings" |
| `.denied` | `denied` | full-screen permission state | "Open Settings" |
| `.restricted` | `restricted` | full-screen permission state | explains device restriction (Open Settings may not help) |

`granted` maps from `.authorized` only — `.limited` is deliberately excluded.

## Components

1. **`PhotoAccessState`** (new file, `Models/`) — the enum above plus
   `init(_ status: PHAuthorizationStatus)`. Single source of truth for the UI.

2. **`PhotoLibrary` protocol + `PhotoLibraryService`** — add a **synchronous**
   `var currentAuthorizationStatus: PHAuthorizationStatus { get }`
   (`PHPhotoLibrary.authorizationStatus(for: .readWrite)` is already
   synchronous). Lets `ScanStore` know the real status immediately at init.
   The test fake gains a settable backing value.

3. **`ScanStore`** —
   - sync the real status at `init` via `currentAuthorizationStatus`;
   - `func refreshAuthorizationStatus()` for foreground re-checks;
   - computed `var photoAccess: PhotoAccessState`;
   - `func requestAccess() async` — calls `requestAuthorization()` then re-syncs;
   - tighten the `runScan` guard to `.authorized` only (limited is handled as
     insufficient upstream);
   - denial no longer depends on `lastError` for the UI (the gate state drives
     it); `lastError` may remain for genuine scan errors.

4. **`PhotoAccessView`** (new file, `Scenes/Permission/`) — branded full-screen
   view (Jost type, AppTheme colors, stair-step logo). Renders priming vs.
   recovery copy from the `PhotoAccessState`; exposes an `onPrimaryAction`
   closure. Accessible: Dynamic Type, VoiceOver label/traits on the action,
   respects Reduce Motion.

5. **`ScanTransitionView`** — insert the gate:
   - `denied` / `needsFullAccess` / `restricted` → swap `PhotoAccessView` in
     place of the SCAN content;
   - `needsPriming` → SCAN tap presents priming `PhotoAccessView` as a
     `.fullScreenCover`; on grant, auto-start the scan; on denial the home
     reflects the new status (recovery state);
   - `granted` → unchanged.

6. **Root (`ImageCleanerApp` / `SplashView`)** — `.onChange(of: scenePhase)` →
   `.active` calls `refreshAuthorizationStatus()`, so granting in Settings and
   returning clears the gate.

## Flows

- **Fresh install:** splash → SCAN hero → tap SCAN → priming cover
  ("Allow Access") → system dialog → granted → scan starts. This registers the
  app in Settings → Privacy → Photos (fixes root cause 2) and fires immediately
  on tap, not after the 2.2s delay.
- **Denies at the dialog:** status syncs to `.denied` → home flips to the
  full-screen recovery state with Open Settings (fixes root cause 1).
- **Returning denied/limited user:** status synced at launch → home shows the
  recovery state immediately.
- **Grants in Settings, returns:** scenePhase refresh → `granted` → gate clears.

## Edge cases

- **Restricted** (Screen Time / MDM): copy states access is restricted by the
  device rather than promising a fix.
- **Saved results + revoked access (option a):** launch-into-results still
  opens; PhotoKit thumbnails may render blank; scan/delete attempts surface the
  gate. No special results-screen rework in this scope.

## Testing

Swift Testing (`@Test`, `#expect`) with the existing `PhotoLibrary` fake,
extended with the new synchronous accessor:

- `PHAuthorizationStatus → PhotoAccessState` mapping for all five statuses;
- `runScan` bails cleanly (no scan, isScanning false) for every non-authorized
  status;
- `requestAccess()` updates `authorizationStatus` / `photoAccess` from the
  fake's returned status.

View-level behavior (dialog, Settings deep-link, scenePhase refresh) is verified
manually in the simulator — the system permission dialog cannot be driven from
unit tests.

## Out of scope

- Reworking the saved-results screen for blank-thumbnail handling under revoked
  access.
- Any change to the duplicate/blank/screenshot detection algorithms.
- A "scan selected photos anyway" affordance under `.limited` (limited is
  treated as insufficient per the decision above).
