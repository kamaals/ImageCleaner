import Testing
import SwiftUI
@testable import ImageCleaner

struct AppThemeTests {
    @Test func defaultAppearanceModeIsSystem() {
        let theme = AppTheme()
        #expect(theme.appearanceMode == .system)
    }

    @Test func systemModeResolvesToNil() {
        let theme = AppTheme()
        #expect(theme.resolvedColorScheme == nil)
    }

    @Test func lightModeResolvesToLight() {
        let theme = AppTheme()
        theme.appearanceMode = .light
        #expect(theme.resolvedColorScheme == .light)
    }

    @Test func darkModeResolvesToDark() {
        let theme = AppTheme()
        theme.appearanceMode = .dark
        #expect(theme.resolvedColorScheme == .dark)
    }
}
