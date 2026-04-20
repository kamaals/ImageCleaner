import SwiftUI

/// Detail sheet for a single standalone photo. Equivalent to
/// `DuplicateCompareSheet` but for non-duplicate images — no side-by-side
/// comparison, just one large image plus a delete action.
struct SinglePhotoViewerSheet<Icon: View>: View {
    let photo: SinglePhoto
    let title: String
    @ViewBuilder let icon: () -> Icon
    var foreground: Color
    var background: Color
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
                .padding(.top, 24)
                .padding(.horizontal, AppLayout.horizontalInset)

            Spacer()

            imageSection
                .padding(.horizontal, AppLayout.horizontalInset)

            Spacer()

            deleteButton
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            icon()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.jost(size: 24, weight: 500))
                    .foregroundStyle(foreground)

                HStack(alignment: .center, spacing: 8) {
                    Text(photo.formattedFileSize)
                        .font(AppFont.jost(size: 16, weight: 400))

                    Circle()
                        .fill(.secondary)
                        .frame(width: 4, height: 4)

                    Text(photo.formattedCreatedAt)
                        .font(AppFont.jost(size: 16, weight: 400))

                    Spacer()
                }
                .foregroundStyle(AppPalette.secondaryText)
            }
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        AssetThumbnailView(
            localIdentifier: photo.localIdentifier,
            placeholderShade: photo.shade,
            pixelSize: 512
        )
        .aspectRatio(0.75, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 12))
        .frame(maxWidth: 260)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Photo thumbnail")
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                onDelete()
            }
        } label: {
            Label("Delete Photo", systemImage: "trash")
                .font(AppFont.jost(size: 18, weight: 500))
                .foregroundStyle(background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(foreground, in: Capsule())
        }
        .padding(.horizontal, AppLayout.horizontalInset)
        .accessibilityLabel("Delete photo")
    }
}

#Preview("Blank photo") {
    SinglePhotoViewerSheet(
        photo: SinglePhoto(shade: 0.92, displayHeight: 180, fileSize: 320_000),
        title: "Blank Photo",
        icon: { LayersIcon(foreground: .black, invertedForeground: .white, skipAnimation: true) },
        foreground: .black,
        background: .white,
        onDelete: {}
    )
    .presentationDetents([.medium])
}

#Preview("Screenshot") {
    SinglePhotoViewerSheet(
        photo: SinglePhoto(shade: 0.35, displayHeight: 240, fileSize: 2_400_000),
        title: "Screenshot",
        icon: { ScanLinesIcon(foreground: .black, invertedForeground: .white, skipAnimation: true) },
        foreground: .black,
        background: .white,
        onDelete: {}
    )
    .presentationDetents([.medium])
}
