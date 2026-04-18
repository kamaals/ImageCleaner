# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Build & Run

```bash
# Build
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run unit tests (Swift Testing framework)
xcodebuild -scheme ImageCleaner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

No SPM dependencies — pure Xcode project.

## Architecture

- **Platform**: iOS 18.0+, Swift 5, SwiftUI App lifecycle
- **Data layer**: SwiftData (`@Model`, `ModelContainer`, `@Query`)
- **UI font**: Futura (system-bundled, via `AppFont` enum)
- **Theme**: `AppTheme` (`@Observable`) with dark/light/system appearance modes
- **Bundle ID**: `me.kamaal.ImageCleaner`

### Targets

| Target | Framework | Purpose |
|--------|-----------|---------|
| `ImageCleaner` | SwiftUI + SwiftData | Main app |
| `ImageCleanerTests` | Swift Testing (`import Testing`) | Unit tests |
| `ImageCleanerUITests` | XCTest / XCUITest | UI + launch performance tests |

### Key conventions

- Models live as `@Model` classes (SwiftData)
- `ModelContainer` is configured in `ImageCleanerApp.swift` via `.modelContainer()` scene modifier
- Views access data through `@Query` and `@Environment(\.modelContext)`
- Unit tests use the modern Swift Testing framework (`@Test`, `#expect`), not XCTest
- Fonts use `AppFont` enum (Futura) — always use `AppFont.body`, `AppFont.title`, etc.
- Appearance mode (dark/light/system) is managed by `AppTheme` via `@Environment`
- Info.plist is auto-generated (`GENERATE_INFOPLIST_FILE = YES`)
