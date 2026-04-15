# SCAN/SCANNING Responsive Layout Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the morphing SCAN / SCANNING display text fit correctly on every iPhone screen size without clipping, and stop the home buttons from overlapping the SCAN text.

**Architecture:** Replace the hardcoded 120pt font size in `ScanTransitionView.swift` with a GeometryReader-driven dynamic size that guarantees "SCAN" fills the available width with a safe horizontal margin. Fix the outer fixed-height frame so it accounts for font line-height (Jost-Black renders ~1.15× font size vertically), preventing the text from bleeding into the home-buttons row beneath it. Remove the negative trailing padding that pushes glyphs off-screen. Preserve the existing morph animation (SCAN → SCANNING via width-clip reveal + scaleEffect) by basing scale math on the newly-dynamic base size rather than a magic constant.

**Tech Stack:** SwiftUI (iOS 26.4+ deployment target), Swift 5, Jost-Black custom font, `.scaleEffect` + `.frame(width:)` for animation, Swift Testing (`import Testing`) for unit tests on view model logic.

---

## Background for the Implementer

### Why each bug happens (root cause)

**Bug 1 — "SCAN" clips the N on the right edge (home state).**
- `ScanTransitionView.swift:115` hardcodes `.font(.custom("Jost-Black", size: 120))`.
- `measureText("SCAN")` at 120pt with `tracking(-4)` ≈ **280 pt wide**.
- On iPhone 17 Pro Max (430 pt wide), the text frame is placed with `.frame(maxWidth: .infinity, alignment: .trailing)` and `.padding(.trailing, -12)` (line 128–130), which pushes the trailing edge 12 pt **past** the screen. Combined with the already tight 280pt width, the "N" visually sits off-screen.
- On narrower devices (iPhone SE: 375 pt) the margin collapses even further.

**Bug 2 — "SCANNING" clips in scan state.**
- Same 120 pt font. `measureText("SCANNING")` ≈ **560 pt**. Even after `.scaleEffect(40/120)` → ~187 pt rendered width, the measurement + frame math runs against the un-scaled 560 pt value in places, and when the transition's `textScale` is mid-animation the clip width is far larger than the scaled display, so glyphs visually bleed past the screen edge. Dynamic base size eliminates this mismatch.

**Bug 3 — Home buttons (View Last Results, Force Re-Scan) overlap SCAN.**
- `ScanTransitionView.swift:122` wraps the text in `.frame(width: clipWidth * scale, height: 120 * scale, alignment: .topLeading)`. The outer frame height is exactly `120 * scale` = 120 pt in home state.
- Jost-Black at 120 pt has a **natural rendered height closer to ~140 pt** (cap height + descender + line-height). SwiftUI's `.frame` does NOT clip; it only reserves layout space. So the text paints ~20 pt **below** the reserved layout rectangle, on top of the next sibling in the `VStack` — which is the `homeButtons` group.
- Fix: either let the text flow at natural height (no fixed-height frame) or multiply by a line-height factor (~1.2).

### Reference design (desired layout)

File: `/Users/kamaalaboothalib/Downloads/iPhone 16 & 17 Pro Max - 2.png`
- "SCAN" spans ~95% of screen width with a small symmetric horizontal margin.
- "View Last Results" + "Force Re-Scan" checkbox sit **below** SCAN, with clear vertical separation (no overlap).
- No horizontal clipping on any glyph.

### Strategy

1. Introduce a `GeometryReader` around the morphing text so we know the available width.
2. Compute a `baseFontSize` such that `measureText("SCAN", size: baseFontSize) ≤ availableWidth - 2 * sidePadding`. Derive it from a reference measurement: `baseFontSize = (availableWidth - 2 * sidePadding) / measureText("SCAN", size: referenceSize) * referenceSize`.
3. The scan-state small size stays a fixed 40 pt (matches existing `targetScale = 40/120` intent).
4. Replace every hardcoded `120` in the morph code path with the dynamic `baseFontSize`.
5. Update `targetScale` on the VM to be a computed function `40.0 / baseFontSize` — since `baseFontSize` is view-local, compute the scale inside the view instead and pass it to the VM via a method, OR keep targetScale dynamic inside the view and let the VM hold just the `0→1` progress.
6. Remove `.padding(.trailing, -12)` (cosmetic offset that now over-pushes) and let the computed `sidePadding` handle margins uniformly.
7. Fix the outer frame: use `height: baseFontSize * scale * lineHeightFactor` where `lineHeightFactor = 1.2` OR drop the fixed height and let the VStack take the text's natural height.

---

## Task 0: Prep — branch & verify baseline builds

**Files:** none (git only)

**Step 1:** Verify we're on the feature branch.

Run: `git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner status -sb`
Expected: on `feature/duplicate-photo-screen` (or a child branch of it).

**Step 2:** Run the existing unit tests to establish the baseline.

Run:
```
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -40
```
Expected: build succeeds. Existing `ScanTransitionViewModelTests` may fail on `homeContentOpacity`/`scanContentOpacity` references — note this; those tests are already stale (the VM does not expose those properties) and will be updated in Task 6. Record the exact failing test names so we know what pre-existed.

**Step 3:** Commit any currently-staged/unstaged cruft BEFORE starting (user has modifications to `project.pbxproj` and `ScanTransitionView.swift` already). Ask the user whether to include or discard — do not decide unilaterally.

---

## Task 1: Add width-measurement helper with reference size

**Files:**
- Modify: `ImageCleaner/Scenes/Home/ScanTransitionView.swift` (replace `measureText` and related helpers)

**Step 1: Understand the existing helper (lines 216–228)**

Current code:
```swift
private var offScreenOffset: CGFloat {
    measureText("SCANNING") + 50
}

private func measureText(_ string: String) -> CGFloat {
    let font = UIFont(name: "Jost-Black", size: 120) ?? .systemFont(ofSize: 120, weight: .black)
    return (string as NSString).size(withAttributes: [.font: font]).width
}
```

The helper is hardcoded to 120pt. We need it to take a size parameter so we can re-use it for any computed size.

**Step 2: Replace with size-parameterised version**

Replace the two helpers with:

```swift
// Reference size we measure against to derive ratios. Any size works mathematically;
// 120 keeps diffs readable vs the old code.
private static let referenceFontSize: CGFloat = 120

/// Width of `string` rendered in Jost-Black at `size` pt, with the -4 pt tracking
/// applied manually (UIFont does not expose tracking, so we adjust afterward).
private func measureText(_ string: String, size: CGFloat = referenceFontSize) -> CGFloat {
    let font = UIFont(name: "Jost-Black", size: size) ?? .systemFont(ofSize: size, weight: .black)
    let rawWidth = (string as NSString).size(withAttributes: [.font: font]).width
    // tracking(-4) in SwiftUI at 120pt removes ~4pt per character gap. Scale linearly.
    let trackingAdjustment = -4 * CGFloat(max(0, string.count - 1)) * (size / Self.referenceFontSize)
    return rawWidth + trackingAdjustment
}

private var offScreenOffset: CGFloat {
    measureText("SCANNING") + 50
}
```

**Step 3:** Verify the file still compiles.

Run: `xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`.

**Step 4: Commit**

```bash
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner add ImageCleaner/Scenes/Home/ScanTransitionView.swift
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner commit -m "refactor(ScanTransitionView): parameterise measureText by size"
```

---

## Task 2: Wrap morphing text in GeometryReader and compute dynamic base size

**Files:**
- Modify: `ImageCleaner/Scenes/Home/ScanTransitionView.swift` — `morphingText` computed property (lines 102–131)

**Step 1: Replace `morphingText` with a GeometryReader-wrapped version**

Replace the entire existing `private var morphingText: some View { ... }` block (lines 102–131) with:

```swift
private var morphingText: some View {
    GeometryReader { geo in
        let sidePadding: CGFloat = 24
        let availableWidth = max(0, geo.size.width - sidePadding * 2)
        // Choose a base font size so that "SCAN" exactly fills availableWidth.
        let scanWidthAtRef = measureText("SCAN", size: Self.referenceFontSize)
        let baseFontSize = (availableWidth / scanWidthAtRef) * Self.referenceFontSize
        // Small scan-state size is a fixed 40pt; derive scale from dynamic base.
        let scanStateFontSize: CGFloat = 40
        let targetScale = scanStateFontSize / baseFontSize
        // Interpolate current scale between 1.0 (home) and targetScale (scan).
        let currentScale = 1.0 + (targetScale - 1.0) * (1 - transition.textScale)
        // NOTE: `transition.textScale` is 1.0 at home and `Self.targetScale` (40/120) in scan.
        // We remap below so the view uses its own dynamic targetScale.
        _ = currentScale // silence unused warning if we pick a different expression below

        let scanWidth = measureText("SCAN", size: baseFontSize)
        let scanningWidth = measureText("SCANNING", size: baseFontSize)
        let clipWidth = scanWidth + (scanningWidth - scanWidth) * transition.textRevealProgress
        // Remap VM's 1.0→(40/120) progress into 1.0→targetScale (dynamic).
        let vmProgress = (1.0 - transition.textScale) / (1.0 - ScanTransitionViewModel.targetScale)
        let scale = 1.0 + (targetScale - 1.0) * vmProgress

        return Button {
            guard !isScanning else { return }
            if reduceMotion { transition.jumpToScanState() }
            else { transition.animateToScan() }
            scanVM.startMockScan()
        } label: {
            Text("SCANNING")
                .font(.custom("Jost-Black", size: baseFontSize, relativeTo: .largeTitle))
                .tracking(-4 * (baseFontSize / Self.referenceFontSize))
                .foregroundStyle(foreground)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: clipWidth, alignment: .leading)
                .clipped()
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: clipWidth * scale,
                    height: baseFontSize * scale * 1.2, // 1.2 accounts for Jost-Black line height
                    alignment: .topLeading
                )
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
        .accessibilityLabel(isScanning ? "Scanning" : "Start scan")
        .opacity(transition.scanningTextVisible ? 1 : 0)
        .offset(x: contentEntered || isScanning ? 0 : offScreenOffset)
        .frame(maxWidth: .infinity, alignment: isScanning ? .leading : .leading)
        .padding(.horizontal, sidePadding)
    }
    .frame(height: Self.referenceFontSize * 1.2) // Reserve enough vertical space for the tallest state
}
```

Key changes vs old code:
- `GeometryReader` gives us `geo.size.width`.
- `baseFontSize` is computed so SCAN fits `availableWidth`.
- `targetScale` is derived from `baseFontSize`, not a VM constant.
- `vmProgress` remaps the VM's existing 1.0 → (40/120) scale-animation into 1.0 → dynamic targetScale so we don't have to change the VM's animation timing logic.
- Removed `.padding(.trailing, -12)` and trailing alignment; SCAN is now leading-aligned and padded symmetrically.
- Outer frame height uses `baseFontSize * scale * 1.2` so rendered text no longer spills below its box.
- Outer GeometryReader gets a static height (`referenceFontSize * 1.2`) so the parent VStack reserves enough room in all states without needing to measure dynamically.

**Step 2:** Build and run on iPhone 17 Pro simulator.

Run:
```
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`.

**Step 3:** Manual visual check.

Boot iPhone 17 Pro simulator, launch ImageCleaner. Verify:
- SCAN fills most of the screen width, neither "S" nor "N" is clipped.
- Tap SCAN → morph happens → SCANNING in top-left is a smaller size and is NOT clipped.
- Back button returns to home and SCAN re-appears cleanly.

**Step 4: Commit**

```bash
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner add ImageCleaner/Scenes/Home/ScanTransitionView.swift
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner commit -m "fix(ScanTransitionView): dynamic font size so SCAN/SCANNING fit any screen"
```

---

## Task 3: Remove home-button overlap by correcting layout stacking

**Files:**
- Modify: `ImageCleaner/Scenes/Home/ScanTransitionView.swift` — `body` (around lines 42–47) + `homeButtons` (lines 135–154)

**Step 1: Remove negative padding from homeButtons, left-align them, and ensure real vertical gap**

Replace the current `homeButtons` invocation in `body` (around lines 43–47):

```swift
// Home buttons — independent of morphingText so they slide out freely
homeButtons
    .padding(.top, 16)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(.trailing, 12)
    .frame(height: isScanning ? 0 : nil)
```

with:

```swift
// Home buttons — sit under morphingText, never overlap
homeButtons
    .padding(.top, 8)
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: isScanning ? 0 : nil)
    .clipped()
```

Reasoning:
- `.frame(maxWidth: .infinity, alignment: .leading)` matches reference (buttons aligned to the left edge, under the "S" of SCAN).
- Dropped the separate `.padding(.trailing, 12)`; horizontal padding is now symmetric with morphingText (24 pt).
- `.clipped()` ensures the buttons truly disappear when the frame collapses to height 0 during scan.
- Reduced top padding from 16 to 8 because the morphingText's outer frame now reserves proper room for descenders.

**Step 2:** Build.

Run:
```
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`.

**Step 3: Visual check on simulator**

- Home state: "View Last Results" appears clearly below SCAN with obvious vertical gap. "Force Re-Scan" checkbox below that. No overlap.
- Tap SCAN → buttons slide out, SCANNING morphs in, no artifacts.

**Step 4: Commit**

```bash
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner add ImageCleaner/Scenes/Home/ScanTransitionView.swift
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner commit -m "fix(ScanTransitionView): left-align home buttons and prevent overlap"
```

---

## Task 4: Verify scan-content horizontal padding matches new 24pt standard

**Files:**
- Inspect: `ImageCleaner/Scenes/Home/ScanTransitionView.swift` — `scanContent` block & its parent invocation (lines 50–53, 158–212)

**Step 1: Check current scanContent padding**

The parent applies `.padding(.horizontal, 24)` at line 53. Good, unchanged. Verify no conflicting padding inside `scanContent` itself by reading lines 158–212.

If any child has `.padding(.horizontal, ...)` that differs from 24, leave it unless it visually misaligns with SCANNING in scan mode. Use the simulator to check.

**Step 2:** No code change expected. If changes needed, keep them minimal (adjust child paddings to 0 so the outer 24 applies cleanly).

**Step 3: Commit only if changes were made**

---

## Task 5: Verify on smallest and largest iPhone simulators

**Files:** none (manual verification)

**Step 1: Build and run on iPhone SE (smallest modern size — 375 pt wide)**

```
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build 2>&1 | tail -5
```

Open simulator manually, launch the app. Verify:
- SCAN fits the screen, both "S" and "N" fully visible.
- Tap SCAN → SCANNING shows in the top-left, fully visible, no clipping.
- Back chevron works and SCAN re-centres correctly.
- Home buttons appear clearly below SCAN.

**Step 2: Repeat on iPhone 17 Pro Max (largest — 430 pt wide)**

```
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Same checks.

**Step 3: Take screenshots of both device simulators in home + scan states.**

Save to: `docs/plans/2026-04-15-scan-text-responsive-layout/`
- `iphone-se-home.png`
- `iphone-se-scanning.png`
- `iphone-17-pro-max-home.png`
- `iphone-17-pro-max-scanning.png`

Use Simulator → Device → Screenshot (⌘S) and move files into place.

**Step 4:** No commit unless screenshots are added.

If screenshots are added:
```bash
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner add docs/plans/2026-04-15-scan-text-responsive-layout/
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner commit -m "docs: capture before/after screenshots for SCAN responsive fix"
```

---

## Task 6: Fix the pre-existing stale unit tests

**Files:**
- Modify: `ImageCleanerTests/ScanTransitionViewModelTests.swift`

**Step 1: Identify failing tests**

Tests at lines 11, 12, 22, 23, 34, 35 reference `homeContentOpacity` and `scanContentOpacity`, which DO NOT exist on `ScanTransitionViewModel`. These tests cannot compile.

**Step 2: Remove the assertions that reference non-existent properties.**

Edit the three affected `@Test` functions: delete the two `#expect(vm.homeContentOpacity == ...)` / `#expect(vm.scanContentOpacity == ...)` lines inside each, leaving the rest of the assertions intact.

**Step 3: Run tests**

```
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```
Expected: all tests pass.

**Step 4: Commit**

```bash
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner add ImageCleanerTests/ScanTransitionViewModelTests.swift
git -C /Users/kamaalaboothalib/Downloads/Projects/iOS/ImageCleaner commit -m "test: remove assertions for properties that no longer exist on ScanTransitionViewModel"
```

---

## Task 7: Final regression sweep

**Files:** none

**Step 1:** Re-run full tests on iPhone 17 Pro.
**Step 2:** Manually walk through: launch → home → tap SCAN → scan animates → completes → navigates to Results → back → re-scan. No clipping, no overlap, no flicker.
**Step 3:** Re-run on iPhone SE to confirm smallest-screen behaviour.
**Step 4:** Done. Branch is ready for review.

---

## Acceptance Criteria (how we know we're done)

1. On iPhone SE, iPhone 17, iPhone 17 Pro Max in both light and dark mode, the "SCAN" text fits within the screen with neither "S" nor "N" clipped.
2. During the scan animation, the small "SCANNING" text in the top-left is never clipped.
3. "View Last Results" and "Force Re-Scan" never overlap the SCAN text — there is a visible vertical gap.
4. The morph animation from SCAN → SCANNING still plays smoothly; the reveal-by-clip effect is preserved.
5. All existing unit tests pass (including any updated to remove stale property references).
6. No hardcoded pixel values tied to a specific device remain in `ScanTransitionView.swift`.

---

## Related Skills

- @swiftui-layout — if any VStack/HStack layout edge cases emerge.
- @swiftui-animations — verify the scale interpolation still feels correct after refactor.
- @swiftui-pro — final review of the updated view for idiomatic SwiftUI.
- @ios-debugging — if the simulator shows unexpected transitions.
