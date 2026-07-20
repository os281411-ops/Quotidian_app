import SwiftUI

struct SplashView: View {
    @State private var animateIn = false

    private struct Glyph {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
        let size: CGFloat
    }

    private let glyphs: [Glyph] = [
        Glyph(text: "S", x: -20, y: -74, rotation: -12, size: 18),
        Glyph(text: "H", x: -48, y: -48, rotation: 8, size: 18),
        Glyph(text: "✦", x: 44, y: -80, rotation: 0, size: 13),
        Glyph(text: "'", x: 60, y: -42, rotation: -20, size: 22),
        Glyph(text: "*", x: 32, y: -8, rotation: 15, size: 18),
        Glyph(text: ")", x: 56, y: 8, rotation: -8, size: 20),
        Glyph(text: "?", x: -60, y: -12, rotation: 18, size: 18)
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    ForEach(Array(glyphs.enumerated()), id: \.offset) { _, glyph in
                        Text(glyph.text)
                            .font(Theme.Font.serif(glyph.size, weight: .light))
                            .foregroundStyle(Theme.textSecondary.opacity(0.5))
                            .rotationEffect(.degrees(glyph.rotation))
                            .offset(x: glyph.x, y: glyph.y)
                    }

                    Image(systemName: "quote.opening")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(Theme.textSecondary.opacity(0.75))
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.85)

                Text("quotidian")
                    .font(Theme.Font.serif(36))
                    .tracking(5)
                    .foregroundStyle(Theme.textPrimary.opacity(0.92))
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
