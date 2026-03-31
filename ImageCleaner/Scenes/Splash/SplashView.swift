import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var heroNamespace
    @State private var isFinished = false

    var body: some View {
        if isFinished {
            ContentView(heroNamespace: heroNamespace)
        } else {
            splash
        }
    }

    private var splash: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 24) {
                AppIconView(
                    foreground: foregroundColor,
                    invertedForeground: backgroundColor
                )
                .frame(width: 160, height: 160)
                .matchedGeometryEffect(id: "appIcon", in: heroNamespace)

                Text("Image Cleaner")
                    .font(AppFont.title)
                    .foregroundStyle(foregroundColor)
                
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3.8))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                isFinished = true
            }
        }
    }
    
    
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
}

#Preview("Light") {
    SplashView()
        .environment(AppTheme())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView()
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
