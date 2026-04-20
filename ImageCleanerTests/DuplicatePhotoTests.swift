import Testing
import Foundation
@testable import ImageCleaner

@MainActor
struct DuplicateImageTests {
    @Test func defaultIDIsUnique() {
        let a = DuplicateImage(shade: 0.5, fileSize: 100)
        let b = DuplicateImage(shade: 0.5, fileSize: 100)
        #expect(a.id != b.id)
    }

    @Test func explicitIDIsPreserved() {
        let id = UUID()
        let img = DuplicateImage(id: id, shade: 0.5, fileSize: 100)
        #expect(img.id == id)
    }

    @Test func formattedFileSizeProducesHumanReadableString() {
        let img = DuplicateImage(shade: 0.5, fileSize: 2_500_000)
        let formatted = img.formattedFileSize
        // ByteCountFormatter is locale-sensitive; sanity-check it contains a digit and "MB"
        #expect(formatted.contains("MB") || formatted.contains("Mb"))
        #expect(formatted.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    @Test func equalityComparesAllStoredProperties() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = DuplicateImage(id: id, shade: 0.4, fileSize: 999, createdAt: date)
        let b = DuplicateImage(id: id, shade: 0.4, fileSize: 999, createdAt: date)
        #expect(a == b)
    }
}

@MainActor
struct DuplicatePhotoTests {
    private func makePhoto(imageCount: Int, baseSize: Int64 = 1_000_000) -> DuplicatePhoto {
        let images = (0..<imageCount).map { i in
            DuplicateImage(shade: Double(i) * 0.1, fileSize: baseSize + Int64(i))
        }
        return DuplicatePhoto(aspectRatio: 1.0, images: images)
    }

    @Test func duplicateCountReflectsImageCount() {
        #expect(makePhoto(imageCount: 2).duplicateCount == 2)
        #expect(makePhoto(imageCount: 3).duplicateCount == 3)
        #expect(makePhoto(imageCount: 5).duplicateCount == 5)
    }

    @Test func primaryShadeIsFirstImageShade() {
        let images = [
            DuplicateImage(shade: 0.42, fileSize: 100),
            DuplicateImage(shade: 0.99, fileSize: 200),
        ]
        let photo = DuplicatePhoto(aspectRatio: 1.0, images: images)
        #expect(photo.primaryShade == 0.42)
    }

    @Test func primaryShadeFallsBackTo05WhenEmpty() {
        let photo = DuplicatePhoto(aspectRatio: 1.0, images: [])
        #expect(photo.primaryShade == 0.5)
    }

    @Test func totalSizeSumsAllImages() {
        let images = [
            DuplicateImage(shade: 0.5, fileSize: 1_000_000),
            DuplicateImage(shade: 0.5, fileSize: 2_500_000),
            DuplicateImage(shade: 0.5, fileSize: 500_000),
        ]
        let photo = DuplicatePhoto(aspectRatio: 1.0, images: images)
        #expect(photo.totalSize == 4_000_000)
    }

    @Test func totalSizeIsZeroWhenEmpty() {
        let photo = DuplicatePhoto(aspectRatio: 1.0, images: [])
        #expect(photo.totalSize == 0)
    }

    @Test func formattedTotalSizeProducesHumanReadableString() {
        let photo = makePhoto(imageCount: 3, baseSize: 1_000_000)
        let formatted = photo.formattedTotalSize
        #expect(formatted.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    @Test func canDeleteMoreOnlyWhenAtLeastTwo() {
        #expect(makePhoto(imageCount: 1).canDeleteMore == false)
        #expect(makePhoto(imageCount: 2).canDeleteMore == true)
        #expect(makePhoto(imageCount: 3).canDeleteMore == true)
    }

    @Test func defaultIsSelectedIsFalse() {
        let photo = makePhoto(imageCount: 2)
        #expect(photo.isSelected == false)
    }

    @Test func mockDataIsNonEmptyAndAllGroupsHaveAtLeastTwoImages() {
        #expect(!DuplicatePhoto.mockData.isEmpty)
        for group in DuplicatePhoto.mockData {
            #expect(group.images.count >= 2, "Mock duplicate group must have ≥ 2 images")
        }
    }
}
