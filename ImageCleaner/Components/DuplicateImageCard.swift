import SwiftUI

struct DuplicateImageCard: View {
    let image: DuplicateImage
    var foreground: Color
    var canDelete: Bool
    var onDelete: () -> Void

    /// Bumped on every confirmed delete tap to drive `.sensoryFeedback` — a
    /// counter rather than a Bool so rapid repeat taps each fire a haptic.
    @State private var deleteTapCount = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AssetThumbnailView(
                    localIdentifier: image.localIdentifier,
                    placeholderShade: image.shade
                )
                .aspectRatio(0.75, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))

                if canDelete {
                    deleteBadge
                }
            }

            // File size label
            Text(image.formattedFileSize)
                .font(AppFont.jost(size: 12, weight: 400))
                .foregroundStyle(AppPalette.secondaryText)
        }
    }

    /// Top-trailing "×" control for removing this duplicate.
    ///
    /// The visible disc is 32pt — restrained, so it never buries the photo —
    /// but the *tap target* is a full 44×44 (the HIG minimum), set by the
    /// outer frame plus `contentShape`. The earlier version applied
    /// `.frame`/`.background` *outside* the `Button`, which left the true hit
    /// area at the ~12pt glyph: a tap had to land dead-centre to register.
    private var deleteBadge: some View {
        Button {
            deleteTapCount += 1
            onDelete()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.red))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(DeleteBadgeButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteTapCount)
        .accessibilityLabel("Delete duplicate")
        .padding(2)
    }
}
