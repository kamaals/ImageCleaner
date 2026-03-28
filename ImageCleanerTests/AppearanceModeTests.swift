import Testing
@testable import ImageCleaner

struct AppearanceModeTests {
    @Test func allCasesContainsThreeModes() {
        #expect(AppearanceMode.allCases.count == 3)
    }

    @Test func displayNames() {
        #expect(AppearanceMode.system.displayName == "System")
        #expect(AppearanceMode.light.displayName == "Light")
        #expect(AppearanceMode.dark.displayName == "Dark")
    }

    @Test func identifiableUsesRawValue() {
        #expect(AppearanceMode.system.id == "system")
        #expect(AppearanceMode.light.id == "light")
        #expect(AppearanceMode.dark.id == "dark")
    }
}
