import SwiftUI

/// View model backing the Blank Photos and Screenshots screens. Same API shape
/// as `DuplicatesViewModel` minus the duplicate-group semantics — each photo
/// stands alone, so there are no per-group aggregates or 2-image-minimum rules.
@Observable @MainActor
final class SinglePhotoCollectionViewModel {
    var photos: [SinglePhoto]
    var selectAll = false
    var selectedPhotoForDetail: SinglePhoto?

    // Animation state (mirrors DuplicatesViewModel so the view animation layer
    // can stay identical).
    var headerVisible = false
    var headerIconReady = false
    var headerIconID = UUID()
    var buttonVisible = false
    var gridVisible = false

    init(photos: [SinglePhoto] = []) {
        self.photos = photos
    }

    /// Two-way binding to a photo by id — used by Pinterest grid cells for
    /// per-photo `isSelected` toggling.
    func binding(for id: UUID) -> Binding<SinglePhoto>? {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                self?.photos[safe: index] ?? self?.photos.first ?? SinglePhoto(shade: 0.5, fileSize: 0)
            },
            set: { [weak self] newValue in
                guard let self, self.photos.indices.contains(index) else { return }
                self.photos[index] = newValue
            }
        )
    }

    // MARK: - Aggregates

    var totalCount: Int { photos.count }

    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    // MARK: - Selection

    var selectedCount: Int {
        photos.count(where: \.isSelected)
    }

    var hasSelection: Bool {
        selectedCount > 0
    }

    var isInSelectionMode: Bool {
        selectAll || hasSelection
    }

    var clearButtonTitle: String {
        hasSelection ? "Clear Selected" : "Clear All"
    }

    // MARK: - Actions

    func toggleSelectAll() {
        selectAll.toggle()
        for index in photos.indices {
            photos[index].isSelected = selectAll
        }
    }

    func setSelectAll(_ value: Bool) {
        selectAll = value
        for index in photos.indices {
            photos[index].isSelected = value
        }
    }

    func clearPhotos() {
        if hasSelection {
            photos.removeAll { $0.isSelected }
        } else {
            photos.removeAll()
        }
        selectAll = false
    }

    func deletePhoto(_ photo: SinglePhoto) {
        photos.removeAll { $0.id == photo.id }
        selectedPhotoForDetail = nil
    }

    func openDetail(for photo: SinglePhoto) {
        guard !isInSelectionMode else { return }
        selectedPhotoForDetail = photo
    }

    func closeDetail() {
        selectedPhotoForDetail = nil
    }

    func currentPhoto(for photoID: UUID) -> SinglePhoto? {
        photos.first { $0.id == photoID }
    }

    // MARK: - Animation

    func jumpToVisible() {
        headerVisible = true
        buttonVisible = true
        gridVisible = true
        headerIconReady = true
    }

    func animateEntrance() {
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.9)

        withAnimation(spring) {
            headerVisible = true
        } completion: {
            self.headerIconReady = true
            self.headerIconID = UUID()
        }

        withAnimation(spring.delay(0.15)) {
            buttonVisible = true
        }

        withAnimation(spring.delay(0.3)) {
            gridVisible = true
        }
    }
}
