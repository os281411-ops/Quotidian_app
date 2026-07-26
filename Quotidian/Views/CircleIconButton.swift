import SwiftUI

struct CircleIconButtonLabel: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    var isEmphasized: Bool = false

    @State private var shinePulse = false
    @State private var rayDrift: Double = 0

    private var diameter: CGFloat { isEmphasized ? 68 : 56 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isEmphasized {
                    // Wide, soft bloom
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: diameter * 1.9, height: diameter * 1.9)
                        .blur(radius: 22)
                        .opacity(shinePulse ? 0.55 : 0.3)

                    // Brighter inner bloom, tighter to the button
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: diameter * 1.25, height: diameter * 1.25)
                        .blur(radius: 12)
                        .opacity(shinePulse ? 0.75 : 0.45)
                        .scaleEffect(shinePulse ? 1.08 : 0.92)

                    // Thin rays of light radiating outward
                    ForEach(0..<8, id: \.self) { i in
                        Capsule()
                            .fill(Theme.accent.opacity(0.45))
                            .frame(width: 2, height: diameter * 0.2)
                            .offset(y: -(diameter / 2 + 6))
                            .rotationEffect(.degrees(Double(i) * 45 + rayDrift))
                    }
                    .opacity(shinePulse ? 0.7 : 0.25)
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
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rayDrift = 360
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
