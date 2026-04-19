import SwiftUI

struct ScanView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = ScanViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            AppIconDrawAnimation()
                .frame(width: 140, height: 140)
                .padding(.top, 24)

            Spacer().frame(height: 24)

            // Title + photo count
            Text("SCANNING")
                .font(.custom("Jost-Black", size: 40, relativeTo: .largeTitle))
                .tracking(1)

            Text("\(viewModel.totalPhotos.formatted()) Photos")
                .font(AppFont.body)
                .padding(.top, 2)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? .white : .black)
                        .frame(width: geo.size.width * viewModel.progress, height: 8)
                        .animation(.linear(duration: 0.1), value: viewModel.progress)
                }
            }
            .frame(height: 8)
            .padding(.top, 12)

            // Scanned count
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.footnote)
                Text("\(viewModel.scannedCount.formatted()) Scanned")
                    .font(AppFont.body)
            }
            .padding(.top, 12)

            // Result rows
            VStack(spacing: 0) {
                ScanResultRow(text: viewModel.duplicatesText, shade: 0.08)
                ScanResultRow(text: viewModel.screenshotsText, shade: 0.13)
                ScanResultRow(text: viewModel.blankPhotosText, shade: 0.18)
            }
            .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, AppLayout.horizontalInset)
        .arrowBackButton(isHidden: viewModel.isScanning)
        .task {
            viewModel.startMockScan()
        }
    }
}

#Preview {
    NavigationStack {
        ScanView()
    }
}
