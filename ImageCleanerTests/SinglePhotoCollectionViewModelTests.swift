import Testing
import Foundation
@testable import ImageCleaner

@MainActor
struct SinglePhotoCollectionViewModelTests {
    private func makeVM(photos: [SinglePhoto] = []) -> SinglePhotoCollectionViewModel {
        SinglePhotoCollectionViewModel(photos: photos)
    }

    private func samplePhoto(fileSize: Int64 = 1_000_000, isSelected: Bool = false) -> SinglePhoto {
        SinglePhoto(shade: 0.5, displayHeight: 120, fileSize: fileSize, isSelected: isSelected)
    }

    // MARK: - Initial state

    @Test func initialStatePreservesProvidedPhotos() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto(), samplePhoto()])
        #expect(vm.photos.count == 3)
        #expect(vm.selectAll == false)
        #expect(vm.selectedPhotoForDetail == nil)
        #expect(vm.headerVisible == false)
        #expect(vm.buttonVisible == false)
        #expect(vm.gridVisible == false)
    }

    @Test func emptyInitIsAllowed() {
        let vm = makeVM()
        #expect(vm.photos.isEmpty)
        #expect(vm.totalCount == 0)
    }

    // MARK: - Aggregates

    @Test func totalCountEqualsPhotoCount() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto()])
        #expect(vm.totalCount == 2)
    }

    @Test func totalSizeSumsAllFileSizes() {
        let vm = makeVM(photos: [
            samplePhoto(fileSize: 1_000),
            samplePhoto(fileSize: 2_500),
            samplePhoto(fileSize: 500),
        ])
        #expect(vm.totalSize == 4_000)
    }

    @Test func formattedTotalSizeIsHumanReadable() {
        let vm = makeVM(photos: [samplePhoto(fileSize: 2_500_000)])
        #expect(vm.formattedTotalSize.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    // MARK: - Selection state

    @Test func selectedCountIsZeroInitially() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto()])
        #expect(vm.selectedCount == 0)
        #expect(vm.hasSelection == false)
    }

    @Test func hasSelectionTrueWhenAnyPhotoSelected() {
        let vm = makeVM(photos: [samplePhoto(isSelected: true), samplePhoto()])
        #expect(vm.hasSelection == true)
        #expect(vm.selectedCount == 1)
    }

    @Test func isInSelectionModeTrueWhenSelectAllOn() {
        let vm = makeVM(photos: [samplePhoto()])
        vm.selectAll = true
        #expect(vm.isInSelectionMode == true)
    }

    @Test func isInSelectionModeTrueWhenAnyPhotoSelected() {
        let vm = makeVM(photos: [samplePhoto(isSelected: true)])
        #expect(vm.isInSelectionMode == true)
    }

    @Test func isInSelectionModeFalseWhenNothingSelected() {
        let vm = makeVM(photos: [samplePhoto()])
        #expect(vm.isInSelectionMode == false)
    }

    @Test func clearButtonTitleDependsOnSelection() {
        let vm = makeVM(photos: [samplePhoto()])
        #expect(vm.clearButtonTitle == "Clear All")

        vm.photos[0].isSelected = true
        #expect(vm.clearButtonTitle == "Clear Selected")
    }

    // MARK: - toggleSelectAll / setSelectAll

    @Test func toggleSelectAllFlipsAndPropagatesToAllPhotos() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto(), samplePhoto()])
        vm.toggleSelectAll()
        #expect(vm.selectAll == true)
        #expect(vm.photos.allSatisfy { $0.isSelected })

        vm.toggleSelectAll()
        #expect(vm.selectAll == false)
        #expect(vm.photos.allSatisfy { !$0.isSelected })
    }

    @Test func setSelectAllFalseClearsExistingSelections() {
        let vm = makeVM(photos: [samplePhoto(isSelected: true), samplePhoto()])
        vm.setSelectAll(false)
        #expect(vm.selectAll == false)
        #expect(vm.photos.allSatisfy { !$0.isSelected })
    }

    // MARK: - clearPhotos

    @Test func clearPhotosRemovesOnlySelectedWhenSomeSelected() {
        let vm = makeVM(photos: [
            samplePhoto(isSelected: true),
            samplePhoto(),
            samplePhoto(isSelected: true),
        ])
        vm.clearPhotos()
        #expect(vm.photos.count == 1)
        #expect(vm.photos.allSatisfy { !$0.isSelected })
        #expect(vm.selectAll == false)
    }

    @Test func clearPhotosRemovesAllWhenNothingSelected() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto()])
        vm.clearPhotos()
        #expect(vm.photos.isEmpty)
        #expect(vm.selectAll == false)
    }

    // MARK: - deletePhoto

    @Test func deletePhotoRemovesFromList() {
        let a = samplePhoto()
        let b = samplePhoto()
        let vm = makeVM(photos: [a, b])
        vm.deletePhoto(a)
        #expect(vm.photos.count == 1)
        #expect(vm.photos.first?.id == b.id)
    }

    @Test func deletePhotoClearsSelectedDetail() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.openDetail(for: photo)
        #expect(vm.selectedPhotoForDetail?.id == photo.id)

        vm.deletePhoto(photo)
        #expect(vm.selectedPhotoForDetail == nil)
    }

    @Test func deletePhotoIsNoOpForUnknownID() {
        let photo = samplePhoto()
        let stranger = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.deletePhoto(stranger)
        #expect(vm.photos.count == 1)
    }

    // MARK: - Detail sheet

    @Test func openDetailSetsSelectedPhotoWhenNotInSelectionMode() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.openDetail(for: photo)
        #expect(vm.selectedPhotoForDetail?.id == photo.id)
    }

    @Test func openDetailIgnoredInSelectionMode() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.selectAll = true
        vm.openDetail(for: photo)
        #expect(vm.selectedPhotoForDetail == nil)
    }

    @Test func closeDetailClearsSelectedPhoto() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.openDetail(for: photo)
        vm.closeDetail()
        #expect(vm.selectedPhotoForDetail == nil)
    }

    @Test func currentPhotoLooksUpByID() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        #expect(vm.currentPhoto(for: photo.id)?.id == photo.id)
        #expect(vm.currentPhoto(for: UUID()) == nil)
    }

    // MARK: - Animation

    @Test func jumpToVisibleSetsAllAnimationFlagsTrue() {
        let vm = makeVM()
        vm.jumpToVisible()
        #expect(vm.headerVisible == true)
        #expect(vm.buttonVisible == true)
        #expect(vm.gridVisible == true)
        #expect(vm.headerIconReady == true)
    }
}
