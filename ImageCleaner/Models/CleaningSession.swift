import Foundation
import SwiftData

@Model
final class CleaningSession {
    var createdAt: Date
    var itemsFound: Int
    var itemsCleaned: Int
    var bytesRecovered: Int64

    init(createdAt: Date = .now, itemsFound: Int = 0, itemsCleaned: Int = 0, bytesRecovered: Int64 = 0) {
        self.createdAt = createdAt
        self.itemsFound = itemsFound
        self.itemsCleaned = itemsCleaned
        self.bytesRecovered = bytesRecovered
    }
}
