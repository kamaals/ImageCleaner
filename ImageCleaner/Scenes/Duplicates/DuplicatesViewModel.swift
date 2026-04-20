import SwiftUI

@Observable @MainActor
final class DuplicatesViewModel {
    // MARK: - State

    var photos: [DuplicatePhoto]
    var selectAll = false
    var selectedPhotoForComparison: DuplicatePhoto?

    init(photos: [DuplicatePhoto] = DuplicatePhoto.mockData) {
        self.photos = photos
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
    }
    
    /// Close comparison sheet
    func closeComparison() {
        selectedPhotoForComparison = nil
    }
    
    /// Get current state of a photo (for sheet updates)
    func currentPhoto(for photoID: UUID) -> DuplicatePhoto? {
        photos.first { $0.id == photoID }
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
