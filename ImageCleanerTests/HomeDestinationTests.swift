import Testing
@testable import ImageCleaner

struct HomeDestinationTests {
    @Test func scanCaseHoldsForceRescan() {
        if case .scan(let force) = HomeDestination.scan(forceRescan: true) {
            #expect(force == true)
        }
    }

    @Test func resultsCaseExists() {
        let d = HomeDestination.results
        #expect(d == .results)
    }

    @Test func settingsCaseExists() {
        let d = HomeDestination.settings
        #expect(d == .settings)
    }

    @Test func conformsToHashable() {
        #expect(HomeDestination.results == HomeDestination.results)
        #expect(HomeDestination.results != HomeDestination.settings)
    }
}
