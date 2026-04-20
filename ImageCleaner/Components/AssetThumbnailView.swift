import SwiftUI

/// Lazy-loading thumbnail view for a PhotoKit asset.
///
/// Uses the canonical `Color.overlay { Image }.clipped()` pattern: the base
/// `Color` claims the proposed size (the cell's explicit width×height), the
/// overlay matches that frame, and the resizable + `.scaledToFill()` image
/// scales into it with center-crop. `.clipped()` on the Color — not on a
/// ZStack — guarantees the rendered thumbnail never extends past the cell's
/// bounds, which was the cause of the prior "wrong-position" clipping bug.
///
/// Thumbnails are streamed from `ScanStore.thumbnailStream(...)` — the cell
/// paints the degraded preview immediately and sharpens in-place once the
/// high-quality delivery lands.
struct AssetThumbnailView: View {
    let localIdentifier: String?
    /// Opacity (0…1) of the gray placeholder shown before the first image lands.
    var placeholderShade: Double = 0.5
    /// PhotoKit thumbnail target size. 384pt keeps cells sharp in a 2-column
    /// Pinterest layout (cell width ≈ 180pt on an iPhone) across @2x/@3x.
    var pixelSize: Int = 384

    @Environment(ScanStore.self) private var store
    @State private var cgImage: CGImage?

    var body: some View {
        Color.gray.opacity(placeholderShade)
            .overlay {
                if let cgImage {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: localIdentifier) {
                guard let id = localIdentifier else { return }
                for await image in store.thumbnailStream(for: id, pixelSize: pixelSize) {
                    await MainActor.run { cgImage = image }
                }
            }
    }
}
