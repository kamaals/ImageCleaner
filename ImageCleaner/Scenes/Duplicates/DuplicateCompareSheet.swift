import SwiftUI

struct DuplicateCompareSheet: View {
    let photo: DuplicatePhoto
    var foreground: Color
    var background: Color
    var onDelete: (DuplicateImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            sheetHeader
                .padding(.top, 24)
                .padding(.horizontal, AppLayout.horizontalInset)
            
            // Images comparison section
            Spacer()
            
            imagesSection
                .padding(.horizontal, AppLayout.horizontalInset)
            
            Spacer()
            
            // Bottom hint
            Text("Tap × to remove a duplicate")
                .font(AppFont.jost(size: 14, weight: 400))
                .foregroundStyle(AppPalette.secondaryText)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
    
    // MARK: - Header
    
    private var sheetHeader: some View {
        HStack(alignment: .center, spacing: 4) {
            // DuplicateIcon - same as the main page
            DuplicateIcon(
                foreground: foreground,
                invertedForeground: background,
                skipAnimation: true
            )
            .frame(width: 56, height: 56)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text("Compare Duplicates")
                    .font(AppFont.jost(size: 24, weight: 500))
                    .foregroundStyle(foreground)
                
                HStack(alignment: .center, spacing: 8) {
                    Text("\(photo.images.count) photos")
                        .font(AppFont.jost(size: 16, weight: 400))
                    
                    Circle()
                        .fill(.secondary)
                        .frame(width: 4, height: 4)
                    
                    Text(photo.formattedTotalSize)
                        .font(AppFont.jost(size: 16, weight: 400))

                    Spacer()
                }
                .foregroundStyle(AppPalette.secondaryText)
            }
        }
    }
    
    // MARK: - Images Section
    
    private var imagesSection: some View {
        HStack(spacing: 12) {
            ForEach(photo.images) { image in
                DuplicateImageCard(
                    image: image,
                    foreground: foreground,
                    canDelete: photo.canDeleteMore,
                    onDelete: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onDelete(image)
                        }
                    }
                )
            }
        }
    }
}

#Preview("2 Duplicates") {
    DuplicateCompareSheet(
        photo: DuplicatePhoto(
            displayHeight: 150,
            images: [
                DuplicateImage(shade: 0.5, fileSize: 2_500_000),
                DuplicateImage(shade: 0.55, fileSize: 2_480_000)
            ]
        ),
        foreground: .black,
        background: .white,
        onDelete: { _ in }
    )
    .presentationDetents([.medium])
}

#Preview("3 Duplicates") {
    DuplicateCompareSheet(
        photo: DuplicatePhoto(
            displayHeight: 150,
            images: [
                DuplicateImage(shade: 0.5, fileSize: 2_500_000),
                DuplicateImage(shade: 0.55, fileSize: 2_480_000),
                DuplicateImage(shade: 0.52, fileSize: 2_520_000)
            ]
        ),
        foreground: .black,
        background: .white,
        onDelete: { _ in }
    )
    .presentationDetents([.medium])
}

#Preview("1 Remaining - No Delete") {
    DuplicateCompareSheet(
        photo: DuplicatePhoto(
            displayHeight: 150,
            images: [
                DuplicateImage(shade: 0.5, fileSize: 2_500_000)
            ]
        ),
        foreground: .black,
        background: .white,
        onDelete: { _ in }
    )
    .presentationDetents([.medium])
}
