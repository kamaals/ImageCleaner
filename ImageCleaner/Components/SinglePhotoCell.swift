import SwiftUI

/// Waterfall cell for a single standalone photo (blank photos, screenshots).
/// Same tap / selection behavior as `DuplicatePhotoCell` but with no duplicate
/// count badge — each cell represents exactly one image.
struct SinglePhotoCell: View {
    @Binding var photo: SinglePhoto
    var foreground: Color
    var isInSelectionMode: Bool = false
    var onTap: (() -> Void)?

    private static let cornerRadius: CGFloat = 14

    var body: some View {
        ZStack(alignment: .topLeading) {
            AssetThumbnailView(
                localIdentifier: photo.localIdentifier,
                placeholderShade: photo.shade
            )

            PhotoSelectionOverlay(isSelected: $photo.isSelected)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            if isInSelectionMode {
                photo.isSelected.toggle()
            } else {
                onTap?()
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SinglePhotoCell(
            photo: .constant(SinglePhoto(shade: 0.92, aspectRatio: 1.0, fileSize: 320_000)),
            foreground: .black,
            isInSelectionMode: false
        )
        .frame(width: 120)

        SinglePhotoCell(
            photo: .constant(SinglePhoto(shade: 0.4, aspectRatio: 1.0, fileSize: 2_100_000, isSelected: true)),
            foreground: .black,
            isInSelectionMode: true
        )
        .frame(width: 120)
    }
    .padding()
}
