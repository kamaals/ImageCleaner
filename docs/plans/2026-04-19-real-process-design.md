# Real Photo Scanning — Design

Date: 2026-04-19
Status: Approved (sections 1–2), implementing remainder

## Goal

Wire the existing PhotoPrune UI prototype (scan progress, home/results/duplicates/blank/screenshots screens, detail sheets) to real iOS Photos-library scanning with SwiftData persistence. No new screens; only real logic behind the screens we already have.

## Scope

- Find **duplicates**, **blank photos**, and **screenshots** in the user's photo library.
- Persist scan report in SwiftData; show the last saved report when the user opens the app.
- Update the report in-place when the user deletes items (from the viewer sheet), so the next "View Last Results" reflects what actually remains.
- Re-scan incrementally on subsequent scans; full re-scan when the user toggles "Force Re-Scan".
- Respect iOS permissions (`.notDetermined`, `.denied`, `.limited`, `.authorized`).

Non-goals: icloud downloads for full-quality compare, burst-photo heuristics, video scans.

---

## 1. Architecture (3 layers)

```
PhotoLibraryService  (actor)          — PhotoKit I/O
        ↓
PhotoScanner         (actor)          — classification + clustering pipeline
        ↓
ScanStore            (@MainActor @Observable, SwiftData-backed)
        ↓
existing ViewModels + Views
```

- **PhotoLibraryService** (`actor`) wraps `PHPhotoLibrary`, `PHAsset.fetchAssets`, `PHImageManager.requestImage`, `PHAssetChangeRequest.deleteAssets`. ~150 lines. Nonisolated from main actor.
- **PhotoScanner** (`actor`) runs the four-phase pipeline. Consumes `PhotoLibraryService`, emits `ScanProgress` via `@Sendable` closure.
- **ScanStore** (`@Observable @MainActor`) owns the `ModelContext`. Exposes view-model–shaped accessors so the existing `DuplicatesViewModel`, `SinglePhotoCollectionViewModel`, and `ResultsView` can drop in with minimal churn.

## 2. Scanning Pipeline

Single async method on `PhotoScanner`:

```swift
func scan(
    forceRescan: Bool,
    onProgress: @Sendable (ScanProgress) -> Void
) async throws -> ScanResult
```

**Phase A — Fetch** (~instant): `PHAsset.fetchAssets(with: .image, options: nil)`. Emits `ScanProgress(total: n)` so the existing "23,567 Photos" label lights up with the real number.

**Phase B — Classify metadata** (~10k/s): read `mediaSubtypes`, `pixelWidth/Height`, `creationDate`. Flags screenshots immediately; builds dimension buckets.

**Phase C — Classify pixels** (slow): batches of 50 with `withThrowingTaskGroup(maxConcurrent: 8)`. For each asset:
- Check cache: if `ScannedAsset` exists with matching dimensions, reuse `dHash`/`brightness`/`variance`.
- Else fetch 64×64 thumbnail, compute:
  - `dHash` — 9×8 grayscale difference hash → `UInt64`
  - `brightness` — mean luminance via `CIAreaAverage`
  - `variance` — 8×8 grid variance
- Emit progress every batch boundary.
- `isBlank = (brightness < 0.05 && variance < 0.01) || variance < 0.0005`.

**Phase D — Cluster** (~fast): group classified assets by `(pixelW, pixelH)`. Within each bucket, greedy Hamming clustering (threshold 5). Buckets with < 2 members discarded.

**Cancellation:** each batch boundary checks `Task.isCancelled`. `ScanViewModel.cancelMockScan` hooks into this.

## 3. SwiftData Schema

Three `@Model` classes, all in `ImageCleaner/Models/`.

```swift
@Model final class ScannedAsset {
    @Attribute(.unique) var localIdentifier: String
    var dHash: Int64         // UInt64 round-tripped as Int64
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var createdAt: Date
    var isScreenshot: Bool
    var isBlank: Bool
    var brightness: Double
    var variance: Double
    var duplicateGroup: DuplicateGroupRecord?  // back-ref
}

@Model final class DuplicateGroupRecord {
    var hashBucket: Int64
    @Relationship(deleteRule: .cascade, inverse: \ScannedAsset.duplicateGroup)
    var members: [ScannedAsset]
}

@Model final class ScanSession {
    var startedAt: Date
    var completedAt: Date?
    var totalScanned: Int
    var duplicateCount: Int       // count of dup groups
    var screenshotCount: Int
    var blankCount: Int
    var reclaimableBytes: Int64   // sum of all-but-largest-in-group + screenshots + blanks
}
```

Only one `ScanSession` is kept at a time — on completion, earlier sessions are deleted. The `CleaningSession` placeholder is removed.

## 4. Incremental Updates

On every scan entry point:

1. **Authorization:** request once; fail fast with friendly UI if denied.
2. **Diff:** `currentIDs = Set(currentFetch.localIdentifiers)`, `cachedIDs = Set(store.scannedAssetIDs)`.
   - `cachedIDs \ currentIDs` → prune (photo deleted outside the app).
   - `currentIDs \ cachedIDs` → new assets to hash.
3. **Dimension check:** for cached assets whose dimensions no longer match, invalidate and re-hash (edited photos).
4. **Force Re-Scan** (toggle on home): skip cache, re-hash everything.
5. **Re-cluster:** always — cheap and handles cache hits.

`PHPhotoLibraryChangeObserver` sets a dirty flag; next app-foreground appearance prompts a fresh scan.

## 5. Deletion flow

Single entry point on `ScanStore`:

```swift
func delete(_ assetIDs: [String]) async throws
```

1. `PhotoLibraryService.deleteAssets([localIds])` → `PHAssetChangeRequest.deleteAssets` inside `performChanges`. iOS shows its system confirmation dialog.
2. On success, `ScanStore` deletes matching `ScannedAsset` rows, re-clusters affected groups, updates `ScanSession` aggregates, saves.
3. On user cancel, no-op.

Used by:
- `DuplicateCompareSheet` — one image at a time via `onDelete:`.
- `SinglePhotoViewerSheet` — one image.
- `DuplicatesDetailView.clearPhotos()` + `SinglePhotoCollectionView.clearPhotos()` — batched (all selected).

## 6. UI wiring (zero new views)

| Existing UI hook                                    | Source of truth                        |
|-----------------------------------------------------|----------------------------------------|
| `ScanViewModel.totalPhotos`                         | `PhotoScanner` Phase A count           |
| `ScanViewModel.scannedCount`                        | `ScanProgress.processed`               |
| `ScanViewModel.duplicatesFound`                     | running duplicate clusters             |
| `ScanViewModel.screenshotsFound`                    | metadata-phase screenshot count        |
| `ScanViewModel.blankPhotosFound`                    | pixel-phase blank count                |
| `ResultsView` "87 items", "376.4 MB"                | `ScanSession.{total, reclaimableBytes}`|
| `ResultsView` per-category counts                   | `ScanSession.{duplicate,screenshot,blank}Count` |
| `DuplicatesViewModel.photos`                        | `store.duplicates`                     |
| `SinglePhotoCollectionViewModel(blanks)`            | `store.blanks`                         |
| `SinglePhotoCollectionViewModel(screenshots)`       | `store.screenshots`                    |
| viewer-sheet Delete                                 | `store.delete(ids:)`                   |
| home "Force Re-Scan" checkbox                       | pass through to `scanner.scan(forceRescan: true)` |

Cells show real thumbnails via `PHCachingImageManager` keyed by `localIdentifier`. Blank/screenshot cells use a small thumbnail; duplicate cells use the group's largest for comparison.

## 7. Edge cases

- **.denied / .restricted:** show a "Open Settings" CTA on the home screen in place of SCAN.
- **.limited:** scan only the shared subset; surface a "Grant full access" hint.
- **Empty library:** results screen renders "Nothing to clean" state.
- **User cancels mid-scan:** progress rolled back, partial session discarded.
- **iCloud-only asset (not on device):** skip gracefully — do not trigger a full-quality download during scan.
- **PhotoKit delete denied by user:** leave store state untouched.

## 8. Testing strategy

Pure helpers unit-tested:
- `dHash` — fixed test images → known hashes (round-trip + distinguishing).
- `hamming` — bit count.
- `brightnessAndVariance` — synthetic images (solid black, solid white, checker).
- `cluster` — synthetic hash list.

`ScanStore` delete + prune logic tested against an in-memory `ModelContainer`.

`PhotoLibraryService` and `PhotoScanner` integration-tested behind a protocol seam so the tests don't need a real Photos library.
