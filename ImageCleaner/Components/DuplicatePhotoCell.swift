import SwiftUI

struct DuplicatePhotoCell: View {
    @Binding var photo: DuplicatePhoto
    var foreground: Color
    var isInSelectionMode: Bool = false
    var onTap: (() -> Void)?

    private static let cornerRadius: CGFloat = 14

    var body: some View {
        ZStack(alignment: .topLeading) {
            AssetThumbnailView(
                localIdentifier: photo.images.first?.localIdentifier,
                placeholderShade: photo.primaryShade
            )

            // Duplicate count badge — opaque pill reads cleanly over both
            // light placeholders and photo thumbnails.
            Text("\(photo.duplicateCount)")
                .font(AppFont.jost(size: 13, weight: 500))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75), in: Capsule())
                .padding(10)

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
        DuplicatePhotoCell(
            photo: .constant(DuplicatePhoto(
                aspectRatio: 1.0,
                images: [
                    DuplicateImage(shade: 0.5, fileSize: 2_500_000),
                    DuplicateImage(shade: 0.55, fileSize: 2_480_000)
                ]
            )),
            foreground: .black,
            isInSelectionMode: false
        )
        .frame(width: 120)

        DuplicatePhotoCell(
            photo: .constant(DuplicatePhoto(
                aspectRatio: 1.0,
                images: [
                    DuplicateImage(shade: 0.7, fileSize: 1_800_000),
                    DuplicateImage(shade: 0.75, fileSize: 1_750_000),
                    DuplicateImage(shade: 0.72, fileSize: 1_820_000)
                ],
                isSelected: true
            )),
            foreground: .black,
            isInSelectionMode: true
        )
        .frame(width: 120)
    }
    .padding()
}
