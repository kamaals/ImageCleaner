import SwiftUI

struct DuplicatesDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }
    
    // Mock data for duplicate photos with varying heights
    @State private var photos: [DuplicatePhoto] = DuplicatePhoto.mockData
    @State private var selectAll = false
    
    // Animation state
    @State private var headerVisible = false
    @State private var headerIconReady = false
    @State private var headerIconID = UUID()
    @State private var buttonVisible = false
    @State private var gridVisible = false
    
    private let offScreenX: CGFloat = -60
    
    // Computed property for selected count
    private var selectedCount: Int {
        photos.filter { $0.isSelected }.count
    }
    
    private var hasSelection: Bool {
        selectedCount > 0
    }
    
    private var clearButtonTitle: String {
        hasSelection ? "Clear Selected Duplicates" : "Clear All Duplicates"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 4) {
                DuplicateIcon(
                    foreground: foreground,
                    invertedForeground: background,
                    skipAnimation: !headerIconReady
                )
                .id(headerIconID)
                .frame(width: 64, height: 64)
                .opacity(headerIconReady ? 1 : 0)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicate Photos")
                        .font(AppFont.jost(size: 28, weight: 500))
                        .foregroundStyle(foreground)
                        .fixedSize()
                    
                    HStack(alignment: .center, spacing: 8) {
                        Text("35 items")
                            .font(AppFont.jost(size: 18, weight: 400))
                        Circle()
                            .fill(.secondary)
                            .frame(width: 5, height: 5)
                        Text("167.9 MB")
                            .font(AppFont.jost(size: 18, weight: 400))
                        Spacer()
                    }
                    
                    .foregroundStyle(.secondary)
                    
                }
                
                Spacer()
                
                // Select all checkbox
                Toggle(isOn: $selectAll) {
                    EmptyView()
                }
                .toggleStyle(CheckboxToggleStyle())
                .onChange(of: selectAll) { _, newValue in
                    for index in photos.indices {
                        photos[index].isSelected = newValue
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .opacity(headerVisible ? 1 : 0)
            .offset(x: headerVisible ? 0 : offScreenX)
            
            // Clear button with 3D shadow effect
            Button {
                clearDuplicates()
            } label: {
                Text(clearButtonTitle)
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
            .padding(.leading, 24)
            .padding(.top, 24)
            .opacity(buttonVisible ? 1 : 0)
            .offset(x: buttonVisible ? 0 : offScreenX)
            
            // Waterfall grid
            ScrollView {
                WaterfallGrid(columns: 3, spacing: 8) {
                    ForEach($photos) { $photo in
                        DuplicatePhotoCell(
                            photo: $photo,
                            foreground: foreground
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
            .opacity(gridVisible ? 1 : 0)
            .offset(y: gridVisible ? 0 : 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if reduceMotion {
                jumpToVisible()
            } else {
                animateEntrance()
            }
        }
        
    }
    
    // MARK: - Actions
    
    private func clearDuplicates() {
        if hasSelection {
            // Clear only selected photos
            photos.removeAll { $0.isSelected }
        } else {
            // Clear all photos
            photos.removeAll()
        }
        selectAll = false
    }
    
    // MARK: - Animation Methods
    
    private func jumpToVisible() {
        headerVisible = true
        buttonVisible = true
        gridVisible = true
    }
    
    private func animateEntrance() {
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.9)
        
        // 1. Header slides in
        withAnimation(spring) {
            headerVisible = true
        } completion: {
            headerIconReady = true
            headerIconID = UUID()
        }
        
        // 2. Button slides in
        withAnimation(spring.delay(0.15)) {
            buttonVisible = true
        }
        
        // 3. Grid fades in
        withAnimation(spring.delay(0.3)) {
            gridVisible = true
        }
    }
}

// MARK: - Duplicate Photo Model

struct DuplicatePhoto: Identifiable {
    let id = UUID()
    let height: CGFloat
    let shade: Double
    var isSelected: Bool
    let duplicateCount: Int?
    
    static let mockData: [DuplicatePhoto] = [
        DuplicatePhoto(height: 180, shade: 0.5, isSelected: false, duplicateCount: 2),
        DuplicatePhoto(height: 120, shade: 0.85, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 160, shade: 0.6, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 100, shade: 0.7, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 200, shade: 0.45, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 140, shade: 0.55, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 80, shade: 0.75, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 220, shade: 0.5, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 110, shade: 0.65, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 170, shade: 0.4, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 130, shade: 0.8, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 150, shade: 0.35, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 90, shade: 0.55, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 180, shade: 0.45, isSelected: false, duplicateCount: nil),
        DuplicatePhoto(height: 120, shade: 0.7, isSelected: false, duplicateCount: nil),
    ]
}

// MARK: - Duplicate Photo Cell

struct DuplicatePhotoCell: View {
    @Binding var photo: DuplicatePhoto
    var foreground: Color
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Photo placeholder
            Rectangle()
                .fill(Color.gray.opacity(photo.shade))
                .frame(height: photo.height)
            
            // Duplicate count badge
            if let count = photo.duplicateCount {
                Text("\(count)")
                    .font(AppFont.jost(size: 12, weight: 500))
                    .foregroundStyle(foreground)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.3))
                    .padding(6)
            }
            
            // Selection checkbox
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Toggle(isOn: $photo.isSelected) {
                        EmptyView()
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .padding(8)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DuplicatesDetailView()
            .environment(AppTheme())
    }
}
