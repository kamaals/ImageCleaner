import SwiftUI

struct ResultsView: View {
    var body: some View {
        VStack {
            Spacer()

            Text("No results yet")
                .font(AppFont.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .navigationTitle("Results")
    }
}

#Preview {
    NavigationStack {
        ResultsView()
    }
}
