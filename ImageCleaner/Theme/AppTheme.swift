import SwiftUI

@Observable
final class AppTheme {
    var appearanceMode: AppearanceMode = .system

    var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
