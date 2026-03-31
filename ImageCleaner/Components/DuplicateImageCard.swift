import SwiftUI

struct DuplicateImageCard: View {
    let image: DuplicateImage
    var foreground: Color
    var canDelete: Bool
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Image with delete button
            ZStack(alignment: .topTrailing) {
                // Image placeholder
                Rectangle()
                    .fill(Color.gray.opacity(image.shade))
                    .aspectRatio(0.75, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))

                // Delete button (only show if can delete)
                if canDelete {
                    Button("Delete duplicate", systemImage: "xmark") {
                        onDelete()
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.9))
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .padding(8)
                }
            }

            // File size label
            Text(image.formattedFileSize)
                .font(AppFont.jost(size: 12, weight: 400))
                .foregroundStyle(.secondary)
        }
    }
}
