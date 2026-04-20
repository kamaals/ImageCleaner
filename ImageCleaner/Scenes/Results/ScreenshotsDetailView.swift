import SwiftUI

struct ScreenshotsDetailView: View {
    @Environment(ScanStore.self) private var store
    @State private var viewModel = SinglePhotoCollectionViewModel()

    var body: some View {
        SinglePhotoCollectionView(
            title: "Screenshots",
            icon: { skipAnimation in
                ScanLinesIcon(skipAnimation: skipAnimation)
            },
            viewModel: viewModel,
            onDeleteRequest: { ids in
                Task { await store.delete(assetIDs: ids) }
            }
        )
        .onAppear {
            viewModel.photos = store.screenshots
        }
        .onChange(of: store.screenshots) { _, new in
            viewModel.photos = new
        }
    }
}
