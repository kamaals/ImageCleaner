import SwiftUI

struct DuplicatesDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Duplicate Photos",
            systemImage: "doc.on.doc",
            description: Text("35 duplicate photos found.")
        )
        .navigationTitle("Duplicates")
        .navigationBarTitleDisplayMode(.inline)
    }
}
