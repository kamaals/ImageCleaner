import SwiftUI

struct BlankPhotosDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Blank Photos",
            systemImage: "photo",
            description: Text("7 blank photos found.")
        )
        .navigationTitle("Blank Photos")
        .navigationBarTitleDisplayMode(.inline)
        .arrowBackButton()
    }
}
