import Testing
import SwiftUI
import UIKit
@testable import ImageCleaner

/// Tests for `AppPalette` and the `Color(light:dark:)` dynamic initializer.
/// The dynamic `Color` backs onto `UIColor { trait in ... }`, so we resolve
/// it against explicit light/dark `UITraitCollection`s to verify each branch.
@MainActor
struct AppPaletteTests {
    @Test func secondaryTextResolvesToLightValueInLightMode() {
        let uiColor = UIColor(AppPalette.secondaryText)
        let resolved = uiColor.resolvedColor(with: .init(userInterfaceStyle: .light))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Light-mode value is (0.32, 0.32, 0.32). Small floating-point tolerance.
        #expect(abs(r - 0.32) < 0.01)
        #expect(abs(g - 0.32) < 0.01)
        #expect(abs(b - 0.32) < 0.01)
    }

    @Test func secondaryTextResolvesToDarkValueInDarkMode() {
        let uiColor = UIColor(AppPalette.secondaryText)
        let resolved = uiColor.resolvedColor(with: .init(userInterfaceStyle: .dark))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Dark-mode value is (0.78, 0.78, 0.78).
        #expect(abs(r - 0.78) < 0.01)
        #expect(abs(g - 0.78) < 0.01)
        #expect(abs(b - 0.78) < 0.01)
    }

    @Test func colorLightDarkInitProducesDifferentValuesInEachTrait() {
        // Use explicit RGB so the comparison is deterministic — SwiftUI's
        // `Color.red` is a dynamic asset-backed color and may not have
        // identical representations across traits.
        let pureRed = Color(red: 1, green: 0, blue: 0)
        let pureBlue = Color(red: 0, green: 0, blue: 1)
        let color = Color(light: pureRed, dark: pureBlue)
        let uiColor = UIColor(color)

        let light = uiColor.resolvedColor(with: .init(userInterfaceStyle: .light))
        let dark = uiColor.resolvedColor(with: .init(userInterfaceStyle: .dark))

        #expect(light != dark)
    }

    @Test func colorLightDarkInitResolvesLightBranchCorrectly() {
        let pureRed = Color(red: 1, green: 0, blue: 0)
        let pureBlue = Color(red: 0, green: 0, blue: 1)
        let color = Color(light: pureRed, dark: pureBlue)
        let uiColor = UIColor(color)
        let light = uiColor.resolvedColor(with: .init(userInterfaceStyle: .light))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        light.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(r > 0.95)
        #expect(g < 0.05)
        #expect(b < 0.05)
    }
}
