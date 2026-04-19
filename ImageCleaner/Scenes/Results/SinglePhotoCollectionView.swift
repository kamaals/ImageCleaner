import SwiftUI

/// Generic detail screen for a collection of standalone photos. Shared by the
/// Blank Photos and Screenshots routes — both use the same header / clear
/// button / waterfall / viewer-sheet layout; only the title and icon differ.
///
/// Deliberately kept parallel to `DuplicatesDetailView` so the two screens
/// read the same and any animation/layout tweak can be applied in lockstep.
struct SinglePhotoCollectionView<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: (_ skipAnimation: Bool) -> Icon
    @State var viewModel: SinglePhotoCollectionViewModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    private let offScreenX: CGFloat = -60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            clearButton
            gridSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if reduceMotion {
                viewModel.jumpToVisible()
            } else {
                viewModel.animateEntrance()
            }
        }
        .sheet(item: $viewModel.selectedPhotoForDetail) { photo in
            if let currentPhoto = viewModel.currentPhoto(for: photo.id) {
                SinglePhotoViewerSheet(
                    photo: currentPhoto,
                    title: title,
                    icon: { icon(true) },
                    foreground: foreground,
                    background: background,
                    onDelete: {
                        viewModel.deletePhoto(currentPhoto)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Back", systemImage: "arrow.left") {
                dismiss()
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(foreground)
            .frame(minWidth: 44, minHeight: 44)

            icon(!viewModel.headerIconReady)
                .id(viewModel.headerIconID)
                .frame(width: 64, height: 64)
                .opacity(viewModel.headerIconReady ? 1 : 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.jost(size: 28, weight: 500))
                    .foregroundStyle(foreground)
                    .fixedSize()

                HStack(alignment: .center, spacing: 8) {
                    Text("\(viewModel.totalCount) items")
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
            viewModel.clearPhotos()
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

    // MARK: - Grid

    private var gridSection: some View {
        ScrollView {
            WaterfallGrid(columns: 3, spacing: 8) {
                ForEach($viewModel.photos) { $photo in
                    SinglePhotoCell(
                        photo: $photo,
                        foreground: foreground,
                        isInSelectionMode: viewModel.isInSelectionMode,
                        onTap: {
                            viewModel.openDetail(for: photo)
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
