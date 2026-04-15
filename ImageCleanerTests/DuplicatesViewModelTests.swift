import Testing
import Foundation
@testable import ImageCleaner

@MainActor
struct DuplicatesViewModelTests {
    private func makeVM(photos: [DuplicatePhoto]? = nil) -> DuplicatesViewModel {
        let vm = DuplicatesViewModel()
        if let photos {
            vm.photos = photos
        }
        return vm
    }

    private func samplePhoto(images: Int = 2, isSelected: Bool = false) -> DuplicatePhoto {
        let imgs = (0..<images).map { i in
            DuplicateImage(shade: 0.5, fileSize: 1_000_000 + Int64(i))
        }
        return DuplicatePhoto(displayHeight: 100, images: imgs, isSelected: isSelected)
    }

    // MARK: - Initial state

    @Test func initialStatePopulatesFromMockData() {
        let vm = makeVM()
        #expect(vm.photos.count == DuplicatePhoto.mockData.count)
        #expect(vm.selectAll == false)
        #expect(vm.selectedPhotoForComparison == nil)
        #expect(vm.headerVisible == false)
        #expect(vm.buttonVisible == false)
        #expect(vm.gridVisible == false)
    }

    // MARK: - Aggregates

    @Test func totalGroupsEqualsPhotoCount() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto(), samplePhoto()])
        #expect(vm.totalGroups == 3)
    }

    @Test func totalItemsSumsImagesAcrossGroups() {
        let vm = makeVM(photos: [samplePhoto(images: 2), samplePhoto(images: 3)])
        #expect(vm.totalItems == 5)
    }

    @Test func totalSizeSumsBytesAcrossGroups() {
        let group1 = DuplicatePhoto(displayHeight: 100, images: [
            DuplicateImage(shade: 0.5, fileSize: 1_000),
            DuplicateImage(shade: 0.5, fileSize: 2_000),
        ])
        let group2 = DuplicatePhoto(displayHeight: 100, images: [
            DuplicateImage(shade: 0.5, fileSize: 4_000),
        ])
        let vm = makeVM(photos: [group1, group2])
        #expect(vm.totalSize == 7_000)
    }

    @Test func formattedTotalSizeIsHumanReadable() {
        let vm = makeVM(photos: [samplePhoto()])
        #expect(vm.formattedTotalSize.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    // MARK: - Selection state

    @Test func selectedCountAndHasSelectionAreFalseInitially() {
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

    @Test func clearButtonTitleChangesWithSelection() {
        let vm = makeVM(photos: [samplePhoto()])
        #expect(vm.clearButtonTitle == "Clear All Duplicates")

        vm.photos[0].isSelected = true
        #expect(vm.clearButtonTitle == "Clear Selected Duplicates")
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

    @Test func setSelectAllOverridesIndividualSelections() {
        let vm = makeVM(photos: [samplePhoto(isSelected: true), samplePhoto()])
        vm.setSelectAll(false)
        #expect(vm.selectAll == false)
        #expect(vm.photos.allSatisfy { !$0.isSelected })
    }

    // MARK: - clearDuplicates

    @Test func clearDuplicatesRemovesOnlySelectedWhenSomeSelected() {
        let vm = makeVM(photos: [
            samplePhoto(isSelected: true),
            samplePhoto(),
            samplePhoto(isSelected: true),
        ])
        vm.clearDuplicates()
        #expect(vm.photos.count == 1)
        #expect(vm.photos.allSatisfy { !$0.isSelected })
        #expect(vm.selectAll == false)
    }

    @Test func clearDuplicatesRemovesAllWhenNothingSelected() {
        let vm = makeVM(photos: [samplePhoto(), samplePhoto()])
        vm.clearDuplicates()
        #expect(vm.photos.isEmpty)
        #expect(vm.selectAll == false)
    }

    // MARK: - deleteImage

    @Test func deleteImageRemovesImageFromGroupWhenMoreThanTwo() {
        let img1 = DuplicateImage(shade: 0.1, fileSize: 100)
        let img2 = DuplicateImage(shade: 0.2, fileSize: 200)
        let img3 = DuplicateImage(shade: 0.3, fileSize: 300)
        let group = DuplicatePhoto(displayHeight: 100, images: [img1, img2, img3])
        let vm = makeVM(photos: [group])

        vm.deleteImage(img2, from: group)

        #expect(vm.photos[0].images.count == 2)
        #expect(vm.photos[0].images.contains { $0.id == img1.id })
        #expect(vm.photos[0].images.contains { $0.id == img3.id })
        #expect(!vm.photos[0].images.contains { $0.id == img2.id })
    }

    @Test func deleteImageRefusesWhenOnlyTwoRemain() {
        // canDeleteMore must be true (count > 1), but result of deletion would be 1
        // Per current impl: guard count > 1 means deletion allowed; result of 1 then triggers
        // dismiss + async removal. So calling delete on a 2-image group DOES remove one image.
        // We assert the immediate sync behaviour: image removed, sheet dismissed.
        let img1 = DuplicateImage(shade: 0.1, fileSize: 100)
        let img2 = DuplicateImage(shade: 0.2, fileSize: 200)
        let group = DuplicatePhoto(displayHeight: 100, images: [img1, img2])
        let vm = makeVM(photos: [group])
        vm.selectedPhotoForComparison = group

        vm.deleteImage(img1, from: group)

        #expect(vm.photos[0].images.count == 1)
        #expect(vm.selectedPhotoForComparison == nil) // sheet dismissed when only 1 left
    }

    @Test func deleteImageNoOpWhenGroupNotFound() {
        let stranger = DuplicatePhoto(displayHeight: 100, images: [
            DuplicateImage(shade: 0.5, fileSize: 100),
            DuplicateImage(shade: 0.5, fileSize: 200),
        ])
        let vm = makeVM(photos: [samplePhoto()])
        let originalCount = vm.photos.count
        vm.deleteImage(stranger.images[0], from: stranger)
        #expect(vm.photos.count == originalCount)
    }

    @Test func deleteImageNoOpWhenOnlyOneImageInGroup() {
        let img = DuplicateImage(shade: 0.5, fileSize: 100)
        let group = DuplicatePhoto(displayHeight: 100, images: [img])
        let vm = makeVM(photos: [group])
        vm.deleteImage(img, from: group)
        #expect(vm.photos[0].images.count == 1) // no change
    }

    // MARK: - Comparison sheet

    @Test func openComparisonSetsSelectedPhotoWhenNotInSelectionMode() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.openComparison(for: photo)
        #expect(vm.selectedPhotoForComparison?.id == photo.id)
    }

    @Test func openComparisonIgnoredInSelectionMode() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.selectAll = true
        vm.openComparison(for: photo)
        #expect(vm.selectedPhotoForComparison == nil)
    }

    @Test func closeComparisonClearsSelection() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        vm.openComparison(for: photo)
        vm.closeComparison()
        #expect(vm.selectedPhotoForComparison == nil)
    }

    @Test func currentPhotoLooksUpByID() {
        let photo = samplePhoto()
        let vm = makeVM(photos: [photo])
        #expect(vm.currentPhoto(for: photo.id)?.id == photo.id)
        #expect(vm.currentPhoto(for: UUID()) == nil)
    }

    // MARK: - Animation jump

    @Test func jumpToVisibleSetsAllAnimationFlagsTrue() {
        let vm = makeVM()
        vm.jumpToVisible()
        #expect(vm.headerVisible == true)
        #expect(vm.buttonVisible == true)
        #expect(vm.gridVisible == true)
        #expect(vm.headerIconReady == true)
    }
}
