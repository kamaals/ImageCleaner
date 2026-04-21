import Foundation

enum HomeDestination: Hashable {
    case scan(forceRescan: Bool)
    case results
    case duplicates
    case similars
    case screenshots
    case blankPhotos
    case settings
}
