import SwiftUI

struct BlankPhotosDetailView: View {
    @Environment(ScanStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = SinglePhotoCollectionViewModel()

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        SinglePhotoCollectionView(
            title: "Blank Photos",
            icon: { skipAnimation in
                // Pass the theme-aware colors through — without them the icon
                // falls back to its `.primary` / `.white` defaults, which
                // collapses to a white-on-white block in dark mode. Mirrors how
                // ResultsView and DuplicatesDetailView color their icons.
                LayersIcon(
                    foreground: foreground,
                    invertedForeground: background,
                    skipAnimation: skipAnimation
                )
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
