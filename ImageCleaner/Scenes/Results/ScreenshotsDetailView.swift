import SwiftUI

struct ScreenshotsDetailView: View {
    @State private var viewModel = SinglePhotoCollectionViewModel(photos: SinglePhoto.screenshotMockData)

    var body: some View {
        SinglePhotoCollectionView(
            title: "Screenshots",
            icon: { skipAnimation in
                ScanLinesIcon(skipAnimation: skipAnimation)
            },
            viewModel: viewModel
        )
    }
}

#Preview {
    NavigationStack {
        ScreenshotsDetailView()
            .environment(AppTheme())
    }
}
