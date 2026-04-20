import SwiftUI

struct BlankPhotosDetailView: View {
    @Environment(ScanStore.self) private var store
    @State private var viewModel = SinglePhotoCollectionViewModel()

    var body: some View {
        SinglePhotoCollectionView(
            title: "Blank Photos",
            icon: { skipAnimation in
                LayersIcon(skipAnimation: skipAnimation)
            },
            viewModel: viewModel,
            onDeleteRequest: { ids in
                Task { await store.delete(assetIDs: ids) }
            }
        )
        .onAppear {
            viewModel.photos = store.blanks
        }
        .onChange(of: store.blanks) { _, new in
            viewModel.photos = new
        }
    }
}
