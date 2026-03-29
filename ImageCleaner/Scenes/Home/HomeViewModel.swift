import SwiftUI

@Observable @MainActor
final class HomeViewModel {
    var forceRescan = false
    var navigationPath = NavigationPath()

    func navigateToScan() {
        navigationPath.append(HomeDestination.scan(forceRescan: forceRescan))
    }

    func navigateToResults() {
        navigationPath.append(HomeDestination.results)
    }
}
