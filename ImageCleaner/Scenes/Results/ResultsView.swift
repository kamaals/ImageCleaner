import SwiftUI

struct ResultsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Results Yet",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Run a scan to find duplicates and screenshots.")
        )
        .navigationTitle("Results")
    }
}

#Preview {
    NavigationStack {
        ResultsView()
    }
}
