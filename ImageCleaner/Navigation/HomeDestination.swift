import Foundation

enum HomeDestination: Hashable {
    case scan(forceRescan: Bool)
    case results
    case settings
}
