import SwiftUI

@Observable @MainActor
final class DuplicatesViewModel {
    // MARK: - State

    var photos: [DuplicatePhoto]
    var selectAll = false
    var selectedPhotoForComparison: DuplicatePhoto?
    /// Snapshot of the compared group's `localIdentifier`s captured when the
    /// sheet opens. `ScanStore.reloadFromPersisted()` rebuilds `DuplicatePhoto`
    /// values with fresh UUIDs after every delete, so a UUID-based lookup
    /// fails as soon as the store reloads. Matching by any surviving asset
    /// id keeps the open sheet pointed at the right group.
    private(set) var comparisonAnchorIDs: Set<String> = []

    init(photos: [DuplicatePhoto] = DuplicatePhoto.mockData) {
        self.photos = photos
    }

    /// Produces a `Binding` to an element of `photos` by id — used by the
    /// Pinterest grid cells so they can two-way bind the per-photo
    /// `isSelected` flag.
    func binding(for id: UUID) -> Binding<DuplicatePhoto>? {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                self?.photos[safe: index] ?? self?.photos.first ?? DuplicatePhoto(images: [])
            },
            set: { [weak self] newValue in
                guard let self, self.photos.indices.contains(index) else { return }
                self.photos[index] = newValue
            }
        )
    }
    
    // Animation state
    var headerVisible = false
    var headerIconReady = false
    var headerIconID = UUID()
    var buttonVisible = false
    var gridVisible = false
    
    // MARK: - Computed Properties
    
    /// Total number of duplicate groups
    var totalGroups: Int {
        photos.count
    }
    
    /// Total number of individual duplicate images
    var totalItems: Int {
        photos.reduce(0) { $0 + $1.duplicateCount }
    }
    
    /// Total size of all duplicates
    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.totalSize }
    }
    
    /// Formatted total size string
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// Number of selected photos
    var selectedCount: Int {
        photos.count(where: \.isSelected)
    }
    
    /// Whether any photo is selected
    var hasSelection: Bool {
        selectedCount > 0
    }
    
    /// Whether in selection mode (any photo selected or selectAll is on)
    var isInSelectionMode: Bool {
        selectAll || hasSelection
    }
    
    /// Button title based on selection state
    var clearButtonTitle: String {
        hasSelection ? "Clear Selected Duplicates" : "Clear All Duplicates"
    }
    
    // MARK: - Actions
    
    /// Toggle select all
    func toggleSelectAll() {
        selectAll.toggle()
        for index in photos.indices {
            photos[index].isSelected = selectAll
        }
    }
    
    /// Set select all state
    func setSelectAll(_ value: Bool) {
        selectAll = value
        for index in photos.indices {
            photos[index].isSelected = value
        }
    }
    
    /// Clear duplicates (selected or all)
    func clearDuplicates() {
        if hasSelection {
            photos.removeAll { $0.isSelected }
        } else {
            photos.removeAll()
        }
        selectAll = false
    }
    
    /// Delete a specific image from a duplicate group
    func deleteImage(_ image: DuplicateImage, from photo: DuplicatePhoto) {
        guard let photoIndex = photos.firstIndex(where: { $0.id == photo.id }) else { return }

        // Only delete if more than 1 image remains
        guard photos[photoIndex].images.count > 1 else { return }

        // Remove the image
        photos[photoIndex].images.removeAll { $0.id == image.id }

        // If only 1 image left, remove the entire duplicate group from the list
        if photos[photoIndex].images.count == 1 {
            // Dismiss the sheet first
            selectedPhotoForComparison = nil
            comparisonAnchorIDs = []

            // Remove the photo group after a short delay for smooth animation
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                await MainActor.run {
                    photos.removeAll { $0.id == photo.id }
                }
            }
        } else {
            // Update the selected photo for comparison to reflect changes
            selectedPhotoForComparison = photos[photoIndex]
        }
    }

    /// Open comparison sheet for a photo
    func openComparison(for photo: DuplicatePhoto) {
        guard !isInSelectionMode else { return }
        selectedPhotoForComparison = photo
        comparisonAnchorIDs = Set(photo.images.compactMap(\.localIdentifier))
    }

    /// Close comparison sheet
    func closeComparison() {
        selectedPhotoForComparison = nil
        comparisonAnchorIDs = []
    }

    /// Get current state of a photo for the open sheet. Prefers the anchor
    /// set captured at open time so the lookup survives `ScanStore` reloads
    /// minting fresh `DuplicatePhoto.id`s; falls back to UUID match for mock
    /// data that has no `localIdentifier`.
    func currentPhoto(for photoID: UUID) -> DuplicatePhoto? {
        if !comparisonAnchorIDs.isEmpty,
           let byAnchor = photos.first(where: { group in
               !Set(group.images.compactMap(\.localIdentifier))
                   .isDisjoint(with: comparisonAnchorIDs)
           }) {
            return byAnchor
        }
        return photos.first { $0.id == photoID }
    }
    
    // MARK: - Animation Methods
    
    private let offScreenX: CGFloat = -60
    
    func jumpToVisible() {
        headerVisible = true
        buttonVisible = true
        gridVisible = true
        headerIconReady = true
    }
    
    func animateEntrance() {
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.9)
        
        // 1. Header slides in
        withAnimation(spring) {
            headerVisible = true
        } completion: {
            self.headerIconReady = true
            self.headerIconID = UUID()
        }
        
        // 2. Button slides in
        withAnimation(spring.delay(0.15)) {
            buttonVisible = true
        }
        
        // 3. Grid fades in
        withAnimation(spring.delay(0.3)) {
            gridVisible = true
        }
    }
}
