import SwiftUI

/// Waterfall cell for a single standalone photo (blank photos, screenshots).
/// Same tap / selection behavior as `DuplicatePhotoCell` but with no duplicate
/// count badge — each cell represents exactly one image.
struct SinglePhotoCell: View {
    @Binding var photo: SinglePhoto
    var foreground: Color
    var isInSelectionMode: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.gray.opacity(photo.shade))
                .frame(height: photo.displayHeight)

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
        SinglePhotoCell(
            photo: .constant(SinglePhoto(shade: 0.92, displayHeight: 150, fileSize: 320_000)),
            foreground: .black,
            isInSelectionMode: false
        )
        .frame(width: 120)

        SinglePhotoCell(
            photo: .constant(SinglePhoto(shade: 0.4, displayHeight: 180, fileSize: 2_100_000, isSelected: true)),
            foreground: .black,
            isInSelectionMode: true
        )
        .frame(width: 120)
    }
    .padding()
}
