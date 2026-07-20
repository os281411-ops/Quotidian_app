import SwiftUI

/// A book glyph that fills from the bottom up as `progress` (0...1) increases,
/// used to show how close the current streak is to its next milestone.
struct BookProgressView: View {
    let progress: Double
    var size: CGFloat = 88

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(systemName: "book.closed")
                .font(.system(size: size))
                .foregroundStyle(Theme.divider)

            Image(systemName: "book.closed.fill")
                .font(.system(size: size))
                .foregroundStyle(Theme.accent)
                .mask(
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().frame(height: size * clampedProgress)
                    }
                    .frame(height: size)
                )
                .animation(.easeOut(duration: 0.5), value: clampedProgress)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack(spacing: 24) {
            BookProgressView(progress: 0.15)
            BookProgressView(progress: 0.6)
            BookProgressView(progress: 0.95)
        }
    }
}
