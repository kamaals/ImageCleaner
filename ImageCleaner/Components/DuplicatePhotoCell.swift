import SwiftUI

struct DuplicatePhotoCell: View {
    @Binding var photo: DuplicatePhoto
    var foreground: Color
    var isInSelectionMode: Bool = false
    var onTap: (() -> Void)?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            AssetThumbnailView(
                localIdentifier: photo.images.first?.localIdentifier,
                placeholderShade: photo.primaryShade
            )
            .frame(height: photo.displayHeight)
            
            // Duplicate count badge — opaque pill so the count reads cleanly
            // over both light placeholders and photo thumbnails.
            Text("\(photo.duplicateCount)")
                .font(AppFont.jost(size: 12, weight: 500))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75), in: Capsule())
                .padding(6)
            
            // Selection checkbox
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Toggle(isOn: $photo.isSelected) {
                        EmptyView()
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(8)
                }
            }
        }
        .contentShape(Rectangle())
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
                displayHeight: 150,
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
                displayHeight: 120,
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
