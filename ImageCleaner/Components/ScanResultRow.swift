import SwiftUI

struct ScanResultRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.quaternary)
    }
}
