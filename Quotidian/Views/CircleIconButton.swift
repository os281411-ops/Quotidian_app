import SwiftUI

struct CircleIconButtonLabel: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    var isEmphasized: Bool = false

    @State private var shinePulse = false

    private var diameter: CGFloat { isEmphasized ? 68 : 56 }

    /// Relative lengths for a sunburst of thin rays — alternating long/short,
    /// like a lens-flare, rather than a few evenly-spaced spokes.
    private let rayLengths: [CGFloat] = [
        1.0, 0.45, 0.85, 0.4, 1.15, 0.45, 0.8, 0.4,
        0.95, 0.45, 0.85, 0.4, 1.05, 0.45, 0.8, 0.4
    ]

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isEmphasized {
                    // Wide, soft bloom
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: diameter * 2.1, height: diameter * 2.1)
                        .blur(radius: 24)
                        .opacity(shinePulse ? 0.55 : 0.3)

                    // Thin sunburst rays, varied length, softly blurred
                    ForEach(Array(rayLengths.enumerated()), id: \.offset) { i, length in
                        Capsule()
                            .fill(Theme.accent.opacity(0.5))
                            .frame(width: 1.5, height: diameter * 0.5 * length)
                            .offset(y: -(diameter / 2 + diameter * 0.25 * length))
                            .blur(radius: 1)
                            .rotationEffect(.degrees(Double(i) * (360.0 / Double(rayLengths.count))))
                    }
                    .opacity(shinePulse ? 0.85 : 0.35)

                    // Brighter inner bloom, tighter to the button
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: diameter * 1.2, height: diameter * 1.2)
                        .blur(radius: 10)
                        .opacity(shinePulse ? 0.8 : 0.5)
                        .scaleEffect(shinePulse ? 1.08 : 0.92)

                    // Hot white-gold core
                    Circle()
                        .fill(Theme.textPrimary)
                        .frame(width: diameter * 0.55, height: diameter * 0.55)
                        .blur(radius: 8)
                        .opacity(shinePulse ? 0.5 : 0.25)
                }

                Circle()
                    .stroke(isActive || isEmphasized ? Theme.accent : Theme.divider, lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                Image(systemName: systemImage)
                    .font(.system(size: isEmphasized ? 20 : 18))
                    .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
        }
        .onAppear {
            guard isEmphasized else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                shinePulse = true
            }
        }
    }
}

struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    var isEmphasized: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIconButtonLabel(systemImage: systemImage, label: label, isActive: isActive, isEmphasized: isEmphasized)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack(spacing: 40) {
            CircleIconButtonLabel(systemImage: "square.and.arrow.up", label: "Share")
            CircleIconButtonLabel(systemImage: "bookmark.fill", label: "Save", isActive: true, isEmphasized: true)
            CircleIconButtonLabel(systemImage: "info.circle", label: "About")
        }
    }
}
