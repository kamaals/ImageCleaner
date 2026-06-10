# Photo Access Permission Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give PhotoPrune a real Photos-permission UX — a priming screen before the first scan, a full-screen recovery state when access is denied/limited/restricted, and correct status syncing — so a tester who declines access sees a clear message and a path to recover instead of a silent, broken app.

**Architecture:** A new `PhotoAccessState` enum (mapped from `PHAuthorizationStatus`) becomes the single source of truth. `ScanStore` syncs the real status at init and on foreground, exposes `photoAccess`, and gains `requestAccess()`. A new branded `PhotoAccessView` renders priming vs. recovery copy. `ScanTransitionView` gates the home: it swaps in `PhotoAccessView` for denied/limited/restricted, and presents a priming `PhotoAccessView` as a full-screen cover on SCAN tap when access is undetermined. `SplashView` suppresses the icon hero for permission-gate launches.

**Tech Stack:** Swift 5, SwiftUI (iOS 18+), SwiftData, PhotoKit (`PHPhotoLibrary`), Swift Testing (`@Test`/`#expect`).

**Spec:** `docs/superpowers/specs/2026-06-10-photo-access-permission-flow-design.md`

---

## File Structure

**Create:**
- `ImageCleaner/Models/PhotoAccessState.swift` — semantic access-state enum + mapping from `PHAuthorizationStatus`.
- `ImageCleaner/Scenes/Permission/PhotoAccessView.swift` — full-screen branded permission view (priming + recovery).
- `ImageCleanerTests/PhotoAccessStateTests.swift` — mapping + `allowsScanning` tests.
- `ImageCleanerTests/ScanStoreAuthorizationTests.swift` — store auth-flow tests.

**Modify:**
- `ImageCleaner/Services/PhotoLibraryService.swift` — add synchronous `currentAuthorizationStatus` to the `PhotoLibrary` protocol + production impl.
- `ImageCleaner/Services/ScanStore.swift` — sync status at init; `refreshAuthorizationStatus()`; `photoAccess`; `requestAccess()`; tighten `runScan` guard to `.authorized`.
- `ImageCleanerTests/ScanStoreDeleteTests.swift` — add `currentAuthorizationStatus` to `StubLibrary` (protocol conformance).
- `ImageCleanerTests/PhotoScannerEndToEndTests.swift` — add `currentAuthorizationStatus` to `FakeLibrary` (protocol conformance).
- `ImageCleaner/Scenes/Home/ScanTransitionView.swift` — gate home content on `photoAccess`; priming full-screen cover; SCAN-tap branch; scenePhase refresh.
- `ImageCleaner/Scenes/Splash/SplashView.swift` — suppress the icon hero for permission-gate launches.

**Reference (read, do not change):**
- `ImageCleaner/Components/AppIconView.swift` — reusable theme-aware app mark (`foreground`, `invertedForeground`, `skipDrawAnimation`).
- `ImageCleaner/Components/PaywallView.swift` — the signature offset-shadow CTA the new button mirrors.
- `ImageCleaner/Theme/AppFont.swift`, `AppLayout.swift`, `AppPalette.swift` — design tokens.

**Build / test commands:**
- Build: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- All tests: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- One suite: append `-only-testing:ImageCleanerTests/PhotoAccessStateTests`

---

## Task 1: `PhotoAccessState` model

**Files:**
- Create: `ImageCleaner/Models/PhotoAccessState.swift`
- Test: `ImageCleanerTests/PhotoAccessStateTests.swift`

- [ ] **Step 1: Write the failing test**

Create `ImageCleanerTests/PhotoAccessStateTests.swift`:

```swift
import Testing
import Photos
@testable import ImageCleaner

struct PhotoAccessStateTests {
    @Test
    func mapsEveryAuthorizationStatus() {
        #expect(PhotoAccessState(.notDetermined) == .needsPriming)
        #expect(PhotoAccessState(.authorized) == .granted)
        #expect(PhotoAccessState(.limited) == .needsFullAccess)
        #expect(PhotoAccessState(.denied) == .denied)
        #expect(PhotoAccessState(.restricted) == .restricted)
    }

    @Test
    func onlyGrantedAllowsScanning() {
        #expect(PhotoAccessState.granted.allowsScanning == true)
        #expect(PhotoAccessState.needsPriming.allowsScanning == false)
        #expect(PhotoAccessState.needsFullAccess.allowsScanning == false)
        #expect(PhotoAccessState.denied.allowsScanning == false)
        #expect(PhotoAccessState.restricted.allowsScanning == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ImageCleanerTests/PhotoAccessStateTests`
Expected: FAIL to compile — `PhotoAccessState` is undefined.

- [ ] **Step 3: Write the implementation**

Create `ImageCleaner/Models/PhotoAccessState.swift`:

```swift
import Photos

/// Semantic Photos-access state the UI binds to. Derived from
/// `PHAuthorizationStatus` so views never branch on PhotoKit enums directly.
///
/// `.limited` maps to `needsFullAccess`: PhotoPrune cleans the *whole* library,
/// and limited access only exposes the user-picked subset — useless for the job.
enum PhotoAccessState: Equatable {
    /// `.notDetermined` — never asked. Show the priming screen, then request.
    case needsPriming
    /// `.authorized` — full access. The only state in which scanning runs.
    case granted
    /// `.limited` — only user-selected photos. Prompt for full access.
    case needsFullAccess
    /// `.denied` — user said no. Recovery is via Settings only (iOS won't re-prompt).
    case denied
    /// `.restricted` — blocked by Screen Time / MDM. The user may be unable to change it.
    case restricted

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .needsPriming
        case .authorized: self = .granted
        case .limited: self = .needsFullAccess
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }

    /// Scanning is permitted only with full access.
    var allowsScanning: Bool { self == .granted }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ImageCleanerTests/PhotoAccessStateTests`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add ImageCleaner/Models/PhotoAccessState.swift ImageCleanerTests/PhotoAccessStateTests.swift
git commit -m "feat(permission): add PhotoAccessState mapped from PHAuthorizationStatus

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 2: Synchronous `currentAuthorizationStatus` on `PhotoLibrary`

This is a compile-level change: the protocol gains a synchronous status read, and all three conformers implement it. No behavior changes yet, so the existing suite must stay green.

**Files:**
- Modify: `ImageCleaner/Services/PhotoLibraryService.swift` (protocol at line 32-45, impl at line 49-68)
- Modify: `ImageCleanerTests/ScanStoreDeleteTests.swift` (`StubLibrary`, line 13-28)
- Modify: `ImageCleanerTests/PhotoScannerEndToEndTests.swift` (`FakeLibrary`, line 15+)

- [ ] **Step 1: Add the protocol requirement + production impl**

In `ImageCleaner/Services/PhotoLibraryService.swift`, add the property to the `PhotoLibrary` protocol. Change:

```swift
protocol PhotoLibrary: Sendable {
    func authorizationStatus() async -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
```

to:

```swift
protocol PhotoLibrary: Sendable {
    /// Synchronous snapshot of the current authorization status. Unlike
    /// `authorizationStatus()`, this never suspends — `PHPhotoLibrary`'s read is
    /// itself synchronous — so callers (e.g. `ScanStore.init`) can seed state
    /// immediately without an async hop.
    var currentAuthorizationStatus: PHAuthorizationStatus { get }
    func authorizationStatus() async -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
```

Then in the `PhotoLibraryService` impl, add the property next to `authorizationStatus()` (after line 60):

```swift
    var currentAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
```

- [ ] **Step 2: Add the property to `StubLibrary`**

In `ImageCleanerTests/ScanStoreDeleteTests.swift`, inside `final class StubLibrary` (after line 16, alongside the other stub methods), add:

```swift
        var currentAuthorizationStatus: PHAuthorizationStatus = .authorized
```

- [ ] **Step 3: Add the property to `FakeLibrary`**

In `ImageCleanerTests/PhotoScannerEndToEndTests.swift`, inside `final class FakeLibrary` (near the existing `authorizationStatus()` at line 24), add:

```swift
        var currentAuthorizationStatus: PHAuthorizationStatus = .authorized
```

- [ ] **Step 4: Verify the whole suite still compiles and passes**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: BUILD SUCCEEDED, all existing tests PASS (no behavior change).

- [ ] **Step 5: Commit**

```bash
git add ImageCleaner/Services/PhotoLibraryService.swift ImageCleanerTests/ScanStoreDeleteTests.swift ImageCleanerTests/PhotoScannerEndToEndTests.swift
git commit -m "feat(permission): add synchronous currentAuthorizationStatus to PhotoLibrary

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 3: `ScanStore` authorization wiring

Sync the real status at init and on demand, expose `photoAccess`, add `requestAccess()`, and tighten the scan guard so only full access scans.

**Files:**
- Modify: `ImageCleaner/Services/ScanStore.swift` (init at line 45-54, scan section at line 97-117)
- Test: `ImageCleanerTests/ScanStoreAuthorizationTests.swift` (create)

- [ ] **Step 1: Write the failing tests**

Create `ImageCleanerTests/ScanStoreAuthorizationTests.swift`:

```swift
import Testing
import SwiftData
import Photos
@testable import ImageCleaner

@MainActor
struct ScanStoreAuthorizationTests {
    /// Configurable PhotoLibrary fake for authorization-flow tests. `current`
    /// is the synchronous status; `requestAuthorization()` flips `current` to
    /// `requestResult` to model the system dialog's outcome.
    final class AuthStubLibrary: PhotoLibrary, @unchecked Sendable {
        var current: PHAuthorizationStatus
        var requestResult: PHAuthorizationStatus

        init(current: PHAuthorizationStatus, requestResult: PHAuthorizationStatus) {
            self.current = current
            self.requestResult = requestResult
        }

        var currentAuthorizationStatus: PHAuthorizationStatus { current }
        func authorizationStatus() async -> PHAuthorizationStatus { current }
        func requestAuthorization() async -> PHAuthorizationStatus {
            current = requestResult
            return requestResult
        }
        func fetchAllPhotoAssets() async -> [PhotoAssetDescriptor] { [] }
        func thumbnailCGImage(localIdentifier: String, pixelSize: Int) async -> CGImage? { nil }
        func thumbnailStream(localIdentifier: String, pixelSize: Int) -> AsyncStream<CGImage> {
            AsyncStream { $0.finish() }
        }
        func deleteAssets(localIdentifiers: [String]) async throws {}
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([ScannedAsset.self, DuplicateGroupRecord.self, ScanSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test
    func photoAccessReflectsRealStatusAtInit() throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .denied, requestResult: .denied)
        let store = ScanStore(modelContext: container.mainContext, library: library)
        #expect(store.photoAccess == .denied)
    }

    @Test
    func requestAccessUpdatesPhotoAccess() async throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .notDetermined, requestResult: .authorized)
        let store = ScanStore(modelContext: container.mainContext, library: library)
        #expect(store.photoAccess == .needsPriming)

        await store.requestAccess()
        #expect(store.photoAccess == .granted)
    }

    @Test
    func refreshPullsLatestStatusFromLibrary() throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .denied, requestResult: .denied)
        let store = ScanStore(modelContext: container.mainContext, library: library)
        #expect(store.photoAccess == .denied)

        // User granted access in Settings; app foregrounds and refreshes.
        library.current = .authorized
        store.refreshAuthorizationStatus()
        #expect(store.photoAccess == .granted)
    }

    @Test
    func runScanBailsWhenAccessIsLimited() async throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .limited, requestResult: .limited)
        let store = ScanStore(modelContext: container.mainContext, library: library)

        await store.runScan(forceRescan: false)

        #expect(store.isScanning == false)
        #expect(store.lastError == "Photo library access denied.")
        #expect(store.latestSession == nil)
    }

    @Test
    func runScanBailsWhenAccessIsDenied() async throws {
        let container = try makeContainer()
        let library = AuthStubLibrary(current: .denied, requestResult: .denied)
        let store = ScanStore(modelContext: container.mainContext, library: library)

        await store.runScan(forceRescan: false)

        #expect(store.isScanning == false)
        #expect(store.lastError == "Photo library access denied.")
        #expect(store.latestSession == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ImageCleanerTests/ScanStoreAuthorizationTests`
Expected: FAIL to compile — `store.photoAccess`, `store.requestAccess()`, `store.refreshAuthorizationStatus()` are undefined; and `photoAccessReflectsRealStatusAtInit` would fail because init does not sync.

- [ ] **Step 3: Sync status at init**

In `ImageCleaner/Services/ScanStore.swift`, in `init` (line 45-54), seed the real status before `reloadFromPersisted()`. Change:

```swift
        self.modelContext = modelContext
        self.library = library
        self.scanner = scanner ?? PhotoScanner(library: library)
        reloadFromPersisted()
```

to:

```swift
        self.modelContext = modelContext
        self.library = library
        self.scanner = scanner ?? PhotoScanner(library: library)
        self.authorizationStatus = library.currentAuthorizationStatus
        reloadFromPersisted()
```

- [ ] **Step 4: Add `photoAccess`, `refreshAuthorizationStatus()`, `requestAccess()`**

In `ImageCleaner/Services/ScanStore.swift`, replace the existing `requestAuthorization()` method (line 99-101):

```swift
    func requestAuthorization() async {
        authorizationStatus = await library.requestAuthorization()
    }
```

with:

```swift
    /// Semantic access state the UI binds to. Derived from the synced
    /// `authorizationStatus` (never the stale `.notDetermined` default).
    var photoAccess: PhotoAccessState { PhotoAccessState(authorizationStatus) }

    /// Re-reads the real system status. Call on `scenePhase == .active` so that
    /// granting access in Settings and returning clears the in-app gate.
    func refreshAuthorizationStatus() {
        authorizationStatus = library.currentAuthorizationStatus
    }

    /// Triggers the system permission dialog (only shown by iOS when status is
    /// `.notDetermined`) and syncs the result. After a prior denial this returns
    /// the existing `.denied` without a dialog — callers must handle that.
    func requestAccess() async {
        authorizationStatus = await library.requestAuthorization()
    }
```

- [ ] **Step 5: Tighten the `runScan` guard to full access only**

In `ImageCleaner/Services/ScanStore.swift`, in `runScan` (line 113), change:

```swift
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            lastError = "Photo library access denied."
            isScanning = false
            return
        }
```

to:

```swift
        // Full access only: `.limited` exposes just the user-picked subset,
        // which a whole-library cleaner can't work with. The UI routes limited
        // users to the recovery screen before they ever reach this guard.
        guard authorizationStatus == .authorized else {
            lastError = "Photo library access denied."
            isScanning = false
            return
        }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ImageCleanerTests/ScanStoreAuthorizationTests`
Expected: PASS (all five tests).

- [ ] **Step 7: Run the full suite (no regressions)**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: All tests PASS. (The `ScanStoreDeleteTests` use `StubLibrary` with `currentAuthorizationStatus = .authorized`, so their scans still run.)

- [ ] **Step 8: Commit**

```bash
git add ImageCleaner/Services/ScanStore.swift ImageCleanerTests/ScanStoreAuthorizationTests.swift
git commit -m "feat(permission): sync real Photos status, expose photoAccess, gate scan on full access

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 4: `PhotoAccessView` (branded full-screen permission UI)

A pure presentation view: it renders priming vs. recovery copy from a `PhotoAccessState` and calls back on the primary button. No business logic, so it's verified by build + previews + manual checks. It matches the brand exactly — monochrome ink/paper, Jost type, the stair-step `AppIconView`, and the signature offset-shadow CTA from `PaywallView`. **No corner radii.**

**Files:**
- Create: `ImageCleaner/Scenes/Permission/PhotoAccessView.swift`

- [ ] **Step 1: Create the view**

Create `ImageCleaner/Scenes/Permission/PhotoAccessView.swift`:

```swift
import SwiftUI
import UIKit

/// Full-screen Photos-permission state shown in place of the SCAN home when the
/// app can't scan: priming before the first request, or a recovery prompt when
/// access is denied / limited / restricted.
///
/// Matches the splash + paywall brand: monochrome ink/paper that inverts with
/// the color scheme, Jost display type, the stair-step app mark, and the
/// signature offset-shadow button (see `PaywallView.ctaSection`). The brand is
/// hard-edged — no corner radii.
struct PhotoAccessView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: PhotoAccessState
    /// Invoked by the primary button. For `.needsPriming` the caller triggers
    /// the system permission request; for the recovery states it deep-links to
    /// Settings.
    let onPrimaryAction: () -> Void

    private var ink: Color { colorScheme == .dark ? .white : .black }
    private var paper: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                AppIconView(
                    foreground: ink,
                    invertedForeground: paper,
                    skipDrawAnimation: true
                )
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
                .padding(.bottom, 40)

                Text("PHOTO ACCESS")
                    .font(AppFont.jost(size: 16, relativeTo: .callout, weight: 500))
                    .tracking(1.5)
                    .foregroundStyle(AppPalette.secondaryText)
                    .padding(.bottom, 8)

                Text(headline)
                    .font(AppFont.jost(size: 48, weight: 900))
                    .foregroundStyle(ink)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 20)

                Text(message)
                    .font(AppFont.jost(size: 17, relativeTo: .body, weight: 400))
                    .foregroundStyle(ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 36)

                primaryButton

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppLayout.horizontalInset)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Signature offset-shadow CTA (mirrors PaywallView.ctaSection)

    private var primaryButton: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(ink)
                .frame(height: 54)
                .offset(x: 6, y: 8)

            Button(action: onPrimaryAction) {
                ZStack {
                    Rectangle()
                        .fill(paper)
                        .overlay(Rectangle().stroke(ink, lineWidth: 0.5))
                    Text(buttonTitle)
                        .font(AppFont.jost(size: 16, relativeTo: .callout, weight: 500))
                        .tracking(2)
                        .foregroundStyle(ink)
                }
                .frame(height: 54)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 6)
        .accessibilityLabel(buttonTitle)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - State copy

    private var headline: String {
        switch state {
        case .needsPriming, .denied, .needsFullAccess: "FULL\nACCESS\nNEEDED"
        case .restricted: "ACCESS\nRESTRICTED"
        case .granted: "FULL\nACCESS\nNEEDED" // unused: granted never renders this view
        }
    }

    private var message: String {
        switch state {
        case .needsPriming:
            "PhotoPrune scans your whole library to find duplicates, screenshots, and blank photos so you can reclaim storage. Your photos never leave your device."
        case .denied:
            "PhotoPrune doesn't have access to your photos. Open Settings and turn on Photos → All Photos to start cleaning up your library."
        case .needsFullAccess:
            "PhotoPrune has limited access — it can only see the photos you picked. To scan your whole library, open Settings and choose All Photos."
        case .restricted:
            "Photo access is restricted on this device, likely by Screen Time or a device-management profile. That restriction has to be lifted before PhotoPrune can scan."
        case .granted:
            ""
        }
    }

    private var buttonTitle: String {
        switch state {
        case .needsPriming: "ALLOW ACCESS"
        case .denied, .needsFullAccess, .restricted: "OPEN SETTINGS"
        case .granted: ""
        }
    }
}

#Preview("Priming — Light") {
    PhotoAccessView(state: .needsPriming, onPrimaryAction: {})
        .preferredColorScheme(.light)
}

#Preview("Denied — Dark") {
    PhotoAccessView(state: .denied, onPrimaryAction: {})
        .preferredColorScheme(.dark)
}

#Preview("Limited — Light") {
    PhotoAccessView(state: .needsFullAccess, onPrimaryAction: {})
        .preferredColorScheme(.light)
}

#Preview("Restricted — Dark") {
    PhotoAccessView(state: .restricted, onPrimaryAction: {})
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Visually verify the previews**

Open `PhotoAccessView.swift` in Xcode and resume the canvas. Confirm all four previews:
- Ink/paper inverts correctly (black-on-white in light, white-on-black in dark).
- The stair-step mark, "PHOTO ACCESS" eyebrow, stacked Jost-900 headline, body, and offset-shadow button all read as part of the same family as the splash and paywall.
- The button has the solid offset shadow down-right of a bordered face (no rounded corners).

- [ ] **Step 4: Commit**

```bash
git add ImageCleaner/Scenes/Permission/PhotoAccessView.swift
git commit -m "feat(permission): add branded PhotoAccessView for priming + recovery

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 5: Gate the home in `ScanTransitionView`

Wrap the home content so denied/limited/restricted show `PhotoAccessView`; present a priming cover on SCAN tap when undetermined; refresh status on foreground.

**Files:**
- Modify: `ImageCleaner/Scenes/Home/ScanTransitionView.swift` (imports line 1-2; properties line 4-28; `body` line 48; SCAN button line 243-261)

- [ ] **Step 1: Add the UIKit import and the priming-cover state**

In `ImageCleaner/Scenes/Home/ScanTransitionView.swift`, change the import block (line 1-2):

```swift
import SwiftUI
import CoreText
```

to:

```swift
import SwiftUI
import CoreText
import UIKit
```

Then add a state property next to the others (after line 13, `pendingScanKickoff`):

```swift
    @State private var showPriming = false
```

- [ ] **Step 2: Rename the current `body` to `homeContent`**

Find `var body: some View {` at line 48. Rename **only that declaration** to:

```swift
    private var homeContent: some View {
```

Leave the entire contents and every trailing modifier (`.geometryGroup()`, `.animation(...)`, `.toolbar { ... }`, `.confirmationDialog(...)`, the `.onAppear { ... }`, etc.) exactly as they are — this becomes the granted/priming home view.

- [ ] **Step 3: Add the new gating `body`**

Immediately above `private var homeContent` (so just before the old line 48), insert:

```swift
    var body: some View {
        Group {
            switch store.photoAccess {
            case .granted, .needsPriming:
                homeContent
            case .denied, .needsFullAccess, .restricted:
                PhotoAccessView(state: store.photoAccess, onPrimaryAction: openPhotoSettings)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshAuthorizationStatus() }
        }
        .fullScreenCover(isPresented: $showPriming) {
            PhotoAccessView(state: .needsPriming) {
                Task { await requestAccessThenMaybeScan() }
            }
        }
    }
```

- [ ] **Step 4: Route the SCAN tap through the access gate**

Find the SCAN button at line 243-261. Replace its action closure. Change:

```swift
            return Button {
                guard !isScanning else { return }
                if reduceMotion {
                    transition.jumpToScanState()
                    scanVM.startScan(store: store, forceRescan: homeVM.forceRescan)
                } else {
                    transition.animateToScan()
                    // Defer scan kickoff until the *entire* intro animation
                    // has settled. Verified by an animate-only isolation test:
                    // the morph + stagger play perfectly with no scan running;
                    // overlapping the scan startup with the animation was the
                    // entire cause of the stutter.
                    pendingScanKickoff?.cancel()
                    pendingScanKickoff = Task { @MainActor in
                        try? await Task.sleep(for: Self.scanKickoffDelay)
                        guard !Task.isCancelled else { return }
                        scanVM.startScan(store: store, forceRescan: homeVM.forceRescan)
                    }
                }
            } label: {
```

to:

```swift
            return Button {
                guard !isScanning else { return }
                handleScanTap()
            } label: {
```

- [ ] **Step 5: Add the scan/permission helper methods**

Add these methods inside `ScanTransitionView` (place them just before `private static func scanLeftOffset` or any existing helper — anywhere in the struct body is fine):

```swift
    /// SCAN-button entry point. Branches on access: scan when granted, prime
    /// when undetermined. The denied/limited/restricted cases are unreachable
    /// here — those states replace `homeContent` with `PhotoAccessView`, so the
    /// SCAN button isn't on screen.
    private func handleScanTap() {
        switch store.photoAccess {
        case .granted:
            startScanFlow()
        case .needsPriming:
            showPriming = true
        case .denied, .needsFullAccess, .restricted:
            break
        }
    }

    /// The original SCAN choreography, unchanged: jump in Reduce Motion, else
    /// animate the morph and defer the scan kickoff past the intro.
    private func startScanFlow() {
        if reduceMotion {
            transition.jumpToScanState()
            scanVM.startScan(store: store, forceRescan: homeVM.forceRescan)
        } else {
            transition.animateToScan()
            pendingScanKickoff?.cancel()
            pendingScanKickoff = Task { @MainActor in
                try? await Task.sleep(for: Self.scanKickoffDelay)
                guard !Task.isCancelled else { return }
                scanVM.startScan(store: store, forceRescan: homeVM.forceRescan)
            }
        }
    }

    /// Priming-cover primary action: request access (shows the system dialog
    /// because status is `.notDetermined`), dismiss the cover, then start the
    /// scan if granted. If denied/limited, `body` swaps in the recovery state.
    private func requestAccessThenMaybeScan() async {
        await store.requestAccess()
        showPriming = false
        if store.photoAccess == .granted {
            startScanFlow()
        }
    }

    /// Recovery primary action: deep-link to the app's Settings page. iOS will
    /// not re-show the permission dialog after a denial, so Settings is the only
    /// path to full access.
    private func openPhotoSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
```

- [ ] **Step 6: Verify it builds**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Run the full suite (no regressions)**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add ImageCleaner/Scenes/Home/ScanTransitionView.swift
git commit -m "feat(permission): gate SCAN home on photo access with priming + recovery

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 6: Suppress the icon hero for permission-gate launches in `SplashView`

When the home will render `PhotoAccessView` inline (denied/limited/restricted), the SCAN icon isn't present, so the splash→home `matchedGeometryEffect` would orphan. Suppress the hero for those launches (same as the existing saved-results path). `.needsPriming` keeps the hero — its home is the normal SCAN screen with a priming cover on top.

**Files:**
- Modify: `ImageCleaner/Scenes/Splash/SplashView.swift` (`body` line 22-35; `hasSavedResults` line 37-41)

- [ ] **Step 1: Add the gate-detection + hero-namespace helpers**

In `ImageCleaner/Scenes/Splash/SplashView.swift`, replace the `body` and `hasSavedResults` block (line 22-41):

```swift
    var body: some View {
        if isFinished {
            // When a completed scan is already saved, open straight into the
            // results and skip the splash→home icon hero (its destination would
            // be hidden behind ResultsView anyway). Otherwise hand off to the
            // SCAN home screen with the hero, as before.
            ContentView(
                heroNamespace: hasSavedResults ? nil : heroNamespace,
                startWithResults: hasSavedResults
            )
        } else {
            splash
        }
    }

    /// A previously completed scan is persisted in SwiftData, so we can show
    /// the last results immediately without re-scanning.
    private var hasSavedResults: Bool {
        store?.latestSession?.isComplete == true
    }
```

with:

```swift
    var body: some View {
        if isFinished {
            // Hand off to the home stack. The icon hero only runs when the
            // destination actually shows the SCAN icon — saved-results and
            // permission-gate launches hide or replace it, so passing the
            // namespace there would orphan the matchedGeometryEffect.
            ContentView(
                heroNamespace: launchHeroNamespace,
                startWithResults: hasSavedResults
            )
        } else {
            splash
        }
    }

    /// A previously completed scan is persisted in SwiftData, so we can show
    /// the last results immediately without re-scanning.
    private var hasSavedResults: Bool {
        store?.latestSession?.isComplete == true
    }

    /// `true` when the home will render the full-screen permission state instead
    /// of the SCAN icon (denied / limited / restricted). `.needsPriming` and
    /// `.granted` are excluded — they show the normal SCAN home.
    private var showsPermissionGate: Bool {
        switch store?.photoAccess {
        case .denied, .needsFullAccess, .restricted: true
        default: false
        }
    }

    /// The icon hero runs only for a normal SCAN-home handoff.
    private var launchHeroNamespace: Namespace.ID? {
        (hasSavedResults || showsPermissionGate) ? nil : heroNamespace
    }
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add ImageCleaner/Scenes/Splash/SplashView.swift
git commit -m "fix(permission): skip splash icon hero when launching into the permission gate

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 7: Full verification

- [ ] **Step 1: Full build + test**

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 2: Manual simulator verification — fresh-install priming + registration**

On a simulator with a **freshly installed** build and a Photos library that has photos:
1. Launch → splash → SCAN home (hero intact). Tap **SCAN**.
2. Confirm the **priming** screen appears ("FULL ACCESS NEEDED", "ALLOW ACCESS"), then tap **ALLOW ACCESS**.
3. Confirm the **system Photos dialog** appears. Tap **Allow Full Access** → the scan starts.
4. Background the app, open **Settings → Privacy & Security → Photos**, and confirm **PhotoPrune now appears** in the list (this verifies the request registered the app — root cause 2).

- [ ] **Step 3: Manual simulator verification — denial + recovery**

Reset the simulator's Photos permission (Settings → General → Transfer or Reset → Reset → Reset Location & Privacy, or delete + reinstall the app):
1. Launch → tap SCAN → priming → ALLOW ACCESS → at the system dialog tap **Don't Allow**.
2. Confirm the home flips to the **recovery** state ("FULL ACCESS NEEDED", "OPEN SETTINGS") — no silent 0-scan (root cause 1).
3. Tap **OPEN SETTINGS** → confirm it deep-links to PhotoPrune's Settings page.
4. In Settings set Photos to **All Photos**, return to the app, and confirm the gate **clears** automatically (scenePhase refresh) and the SCAN home is shown.

- [ ] **Step 4: Manual simulator verification — limited access**

Reset permission again:
1. Launch → tap SCAN → ALLOW ACCESS → at the system dialog choose **Limit Access… → Select Photos** and pick a few.
2. Confirm the home shows the **limited** recovery state ("FULL ACCESS NEEDED", body mentioning limited/All Photos), and that scanning does **not** proceed.

- [ ] **Step 5: Manual simulator verification — saved-results launch (edge case a)**

With full access granted and a completed scan persisted:
1. Force-quit and relaunch → confirm the app opens straight into the saved **Results** (existing behavior preserved).
2. Revoke access in Settings (set Photos to None), return to the app → confirm it still opens results (option a), and that tapping **SCAN** (after popping back home) surfaces the recovery gate rather than silently failing.

- [ ] **Step 6: Final commit if any manual-fix tweaks were needed**

If steps 2-5 required code adjustments, commit them with a descriptive message. Otherwise this task is verification-only.

---

## Self-Review

**Spec coverage:**
- Root cause 1 (silent on refusal) → Task 3 (guard + `lastError` no longer the only signal) + Task 5 (recovery state on home). ✓
- Root cause 2 (not in Settings list) → Task 5 priming flow triggers `requestAuthorization`, verified in Task 7 Step 2. ✓
- Root cause 3 (status never synced) → Task 3 (init sync + `refreshAuthorizationStatus`) + Task 5 (scenePhase refresh). ✓
- Priming before first scan → Task 5 (`showPriming` cover). ✓
- Limited = insufficient → Task 1 mapping + Task 3 guard + Task 5 recovery. ✓
- Full-screen state on home → Task 4 view + Task 5 gate. ✓
- scenePhase recovery → Task 5 Step 3. ✓
- Hero/orphan-geometry interaction → Task 6. ✓
- Saved-results edge case (a) → Task 7 Step 5 (verification; no code change needed since results launch is unchanged). ✓
- Testing (mapping, guard bails, requestAccess, refresh) → Tasks 1 & 3. ✓

**Placeholder scan:** No TBDs; every code step shows complete code; every command has expected output. ✓

**Type consistency:** `PhotoAccessState` cases (`needsPriming`, `granted`, `needsFullAccess`, `denied`, `restricted`) and `allowsScanning` used identically across Tasks 1, 3, 4, 5, 6. `currentAuthorizationStatus`, `refreshAuthorizationStatus()`, `requestAccess()`, `photoAccess` names match across Tasks 2, 3, 5. `homeContent`/`startScanFlow`/`handleScanTap`/`requestAccessThenMaybeScan`/`openPhotoSettings` defined and referenced consistently in Task 5. ✓
