import SwiftUI

/// Lazy-loading thumbnail view for a PhotoKit asset. Pulls the image via
/// `ScanStore.thumbnail(for:pixelSize:)` on appear and falls back to the
/// placeholder shade while loading (or when backed by mock data without a
/// `localIdentifier`).
struct AssetThumbnailView: View {
    let localIdentifier: String?
    /// Opacity (0…1) of the gray placeholder shown before the image lands.
    var placeholderShade: Double = 0.5
    /// PhotoKit thumbnail target size. 256pt is a good balance between
    /// cell sharpness and memory for a 3-column waterfall.
    var pixelSize: Int = 256
    var contentMode: ContentMode = .fill

    @Environment(ScanStore.self) private var store
    @State private var cgImage: CGImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(placeholderShade))

            if let cgImage {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .clipped()
        .task(id: localIdentifier) {
            guard let id = localIdentifier else { return }
            // If the view re-uses across cells, only re-fetch when the
            // identifier actually changes.
            if let loaded = await store.thumbnail(for: id, pixelSize: pixelSize) {
                await MainActor.run { cgImage = loaded }
            }
        }
    }
}
