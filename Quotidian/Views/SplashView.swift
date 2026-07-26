import SwiftUI

struct SplashView: View {
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashReadingFigure")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 180, height: 180)
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.85)

                Text("quotidian")
                    .font(Theme.Font.serif(36))
                    .tracking(5)
                    .foregroundStyle(Theme.accent)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animateIn = true
            }
        }
    }
}

#Preview {
    SplashView()
}
