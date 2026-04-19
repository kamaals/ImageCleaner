import Testing
import SwiftUI
@testable import ImageCleaner

struct AppThemeTests {
    @Test @MainActor func defaultAppearanceModeIsSystem() {
        let theme = AppTheme()
        #expect(theme.appearanceMode == .system)
    }

    @Test @MainActor func systemModeResolvesToNil() {
        let theme = AppTheme()
        #expect(theme.resolvedColorScheme == nil)
    }

    @Test @MainActor func lightModeResolvesToLight() {
        let theme = AppTheme()
        theme.appearanceMode = .light
        #expect(theme.resolvedColorScheme == .light)
    }

    @Test @MainActor func darkModeResolvesToDark() {
        let theme = AppTheme()
        theme.appearanceMode = .dark
        #expect(theme.resolvedColorScheme == .dark)
    }
}
