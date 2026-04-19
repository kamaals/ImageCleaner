import Testing
import SwiftUI
@testable import ImageCleaner

struct CheckboxToggleStyleTests {
    @Test func conformsToToggleStyle() {
        let _: any ToggleStyle = CheckboxToggleStyle()
    }
}
