import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var heroNamespace
    @State private var isFinished = false
    @State private var showWordmark = false

    private let iconSize: CGFloat = 240

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

            ZStack(alignment: .topLeading) {
                AppIconDrawAnimation(onFinished: revealWordmark)
                    .frame(width: iconSize, height: iconSize)
                    .matchedGeometryEffect(id: "appIcon", in: heroNamespace)

                VStack(alignment: .leading, spacing: iconSize * 0.008) {
                    Text("Photo")
                    Text("Prune")
                }
                .font(AppFont.jost(size: iconSize * 0.095, weight: 400))
                .foregroundStyle(foregroundColor)
                .padding(.leading, iconSize * 0.23)
                .padding(.top, iconSize * 0.55)
                .opacity(showWordmark ? 1 : 0)
                .offset(y: showWordmark ? 0 : 6)
                .animation(.easeOut(duration: 0.45), value: showWordmark)
                .accessibilityLabel("PhotoPrune")
            }
            .frame(width: iconSize, height: iconSize)
        }
        .task {
            try? await Task.sleep(for: .seconds(3.8))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                isFinished = true
            }
        }
    }

    private func revealWordmark() {
        showWordmark = true
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
