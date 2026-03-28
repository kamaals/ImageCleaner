import Testing
@testable import ImageCleaner

struct CheckboxToggleStyleTests {
    @Test func checkboxToggleStyleExists() {
        let style = CheckboxToggleStyle()
        #expect(style != nil)
    }
}
