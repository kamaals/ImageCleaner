import SwiftUI

struct DuplicatesDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(ScanStore.self) private var store

    @State private var viewModel = DuplicatesViewModel(photos: [])
    
    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }
    
    private let offScreenX: CGFloat = -60
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
            
            // Clear button with 3D shadow effect
            clearButton
            
            // Waterfall grid
            gridSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.photos = store.duplicates
            if reduceMotion {
                viewModel.jumpToVisible()
            } else {
                viewModel.animateEntrance()
            }
        }
        .onChange(of: store.duplicates) { _, new in
            viewModel.photos = new
        }
        .sheet(item: $viewModel.selectedPhotoForComparison) { photo in
            // Get the current state of the photo from view model
            if let currentPhoto = viewModel.currentPhoto(for: photo.id) {
                DuplicateCompareSheet(
                    photo: currentPhoto,
                    foreground: foreground,
                    background: background,
                    onDelete: { image in
                        if let lid = image.localIdentifier {
                            Task { await store.delete(assetIDs: [lid]) }
                        }
                        viewModel.deleteImage(image, from: currentPhoto)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Back button
            Button("Back", systemImage: "arrow.left") {
                dismiss()
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(foreground)
            .frame(minWidth: 44, minHeight: 44)
            
            DuplicateIcon(
                foreground: foreground,
                invertedForeground: background,
                skipAnimation: !viewModel.headerIconReady
            )
            .id(viewModel.headerIconID)
            .frame(width: 64, height: 64)
            .opacity(viewModel.headerIconReady ? 1 : 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Photos")
                    .font(AppFont.jost(size: 28, weight: 500))
                    .foregroundStyle(foreground)
                    .fixedSize()
                
                HStack(alignment: .center, spacing: 8) {
                    Text("\(viewModel.totalItems) items")
                        .font(AppFont.jost(size: 18, weight: 400))
                    Circle()
                        .fill(.secondary)
                        .frame(width: 5, height: 5)
                    Text(viewModel.formattedTotalSize)
                        .font(AppFont.jost(size: 18, weight: 400))
                    Spacer()
                }
                .foregroundStyle(AppPalette.secondaryText)
            }
            
            Spacer()
            
            // Select all checkbox
            Toggle(isOn: $viewModel.selectAll) {
                EmptyView()
            }
            .toggleStyle(CheckboxToggleStyle())
            .onChange(of: viewModel.selectAll) { _, newValue in
                viewModel.setSelectAll(newValue)
            }
        }
        .padding(.horizontal, AppLayout.horizontalInset)
        .padding(.top, 16)
        .opacity(viewModel.headerVisible ? 1 : 0)
        .offset(x: viewModel.headerVisible ? 0 : offScreenX)
    }
    
    // MARK: - Clear Button
    
    private var clearButton: some View {
        Button {
            // When some photos are selected, we delete only those; otherwise
            // iOS gets every image in every duplicate group.
            let idsToDelete: [String]
            if viewModel.hasSelection {
                idsToDelete = viewModel.photos
                    .filter(\.isSelected)
                    .flatMap(\.images)
                    .compactMap(\.localIdentifier)
            } else {
                idsToDelete = viewModel.photos
                    .flatMap(\.images)
                    .compactMap(\.localIdentifier)
            }
            if !idsToDelete.isEmpty {
                Task { await store.delete(assetIDs: idsToDelete) }
            }
            viewModel.clearDuplicates()
        } label: {
            Text(viewModel.clearButtonTitle)
                .font(AppFont.jost(size: 18, weight: 300))
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(background)
                .overlay(
                    Rectangle()
                        .stroke(foreground, lineWidth: 1)
                )
                .background(
                    Rectangle()
                        .fill(foreground)
                        .offset(x: -4, y: 4)
                )
        }
        .padding(.leading, AppLayout.horizontalInset)
        .padding(.top, 24)
        .opacity(viewModel.buttonVisible ? 1 : 0)
        .offset(x: viewModel.buttonVisible ? 0 : offScreenX)
    }
    
    // MARK: - Grid Section
    
    private var gridSection: some View {
        ScrollView {
            PinterestGrid(
                items: viewModel.photos,
                columns: 3,
                spacing: 8,
                aspectRatio: { $0.aspectRatio }
            ) { photo in
                if let binding = viewModel.binding(for: photo.id) {
                    DuplicatePhotoCell(
                        photo: binding,
                        foreground: foreground,
                        isInSelectionMode: viewModel.isInSelectionMode,
                        onTap: {
                            viewModel.openComparison(for: photo)
                        }
                    )
                }
            }
            .padding(.horizontal, AppLayout.horizontalInset)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .opacity(viewModel.gridVisible ? 1 : 0)
        .offset(y: viewModel.gridVisible ? 0 : 30)
    }
}

#Preview {
    NavigationStack {
        DuplicatesDetailView()
            .environment(AppTheme())
    }
}
