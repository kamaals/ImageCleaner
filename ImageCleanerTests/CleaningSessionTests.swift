import Testing
import Foundation
@testable import ImageCleaner

struct CleaningSessionTests {
    @Test func defaultInitializationValues() {
        let session = CleaningSession()
        #expect(session.itemsFound == 0)
        #expect(session.itemsCleaned == 0)
        #expect(session.bytesRecovered == 0)
    }

    @Test func customInitialization() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let session = CleaningSession(
            createdAt: date, itemsFound: 42,
            itemsCleaned: 10, bytesRecovered: 1_048_576
        )
        #expect(session.itemsFound == 42)
        #expect(session.itemsCleaned == 10)
        #expect(session.bytesRecovered == 1_048_576)
    }
}
