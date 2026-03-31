import SwiftUI

struct ScreenshotsDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Screenshots",
            systemImage: "camera.viewfinder",
            description: Text("67 screenshots found.")
        )
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
    }
}
