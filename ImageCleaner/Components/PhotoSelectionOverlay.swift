import SwiftUI

/// Bottom overlay for Pinterest-grid photo cells: adds a glassy gradient at
/// the bottom so a white checkbox always has enough contrast to be visible
/// against light photos, and anchors the selection control with a fixed
/// 22×22 glyph plus a 44×44 invisible hit target for accessibility.
///
/// The overlay is placed inside the cell's clip bounds so it can't extend
/// beyond the thumbnail edge — the previous implementation relied on a
/// `Toggle` whose inner frame alignment cut the checkbox off at the right.
struct PhotoSelectionOverlay: View {
    @Binding var isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Bottom contrast layer: ultraThinMaterial frosts whatever is
            // behind it (the photo), then a black→clear linear gradient
            // deepens the shadow downward. Height ~44pt is enough to host
            // the checkbox without overpowering the photo above.
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial.opacity(0.6))
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            // Selection glyph — fixed 22pt so it never gets clipped by the
            // cell edge, padded 12pt from the bottom-right corner.
            checkbox
                .frame(width: 44, height: 44) // 44×44 a11y hit target
                .contentShape(Rectangle())
                .onTapGesture { isSelected.toggle() }
                .padding(.trailing, 4)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isToggle)
                .accessibilityValue(isSelected ? "checked" : "unchecked")
                .accessibilityLabel("Select photo")
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? Color.white : Color.clear)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1.5)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 22, height: 22)
    }
}

#Preview {
    ZStack {
        Color.gray
        PhotoSelectionOverlay(isSelected: .constant(true))
    }
    .frame(width: 180, height: 240)
}
