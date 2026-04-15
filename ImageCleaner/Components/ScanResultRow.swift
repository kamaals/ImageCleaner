import SwiftUI

struct ScanResultRow: View {
    let text: String
    /// Visual shade of the row card. Scaled + floored to stay readable on both
    /// color schemes — callers pass 0.08 / 0.13 / 0.18 as relative tiers; we
    /// lift them to 0.10 / 0.16 / 0.22 so the lightest row still reads as a
    /// distinct card instead of blending into the background in light mode.
    var shade: Double = 0.1

    var body: some View {
        Text(text)
            .font(AppFont.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(max(0.10, shade + 0.02)))
    }
}
