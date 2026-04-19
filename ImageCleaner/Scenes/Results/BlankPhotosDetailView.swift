import SwiftUI

struct BlankPhotosDetailView: View {
    @State private var viewModel = SinglePhotoCollectionViewModel(photos: SinglePhoto.blankMockData)

    var body: some View {
        SinglePhotoCollectionView(
            title: "Blank Photos",
            icon: { skipAnimation in
                LayersIcon(skipAnimation: skipAnimation)
            },
            viewModel: viewModel
        )
    }
}

#Preview {
    NavigationStack {
        BlankPhotosDetailView()
            .environment(AppTheme())
    }
}
