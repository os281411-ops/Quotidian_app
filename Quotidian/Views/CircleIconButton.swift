import SwiftUI

struct CircleIconButtonLabel: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    var isEmphasized: Bool = false

    @State private var ringRotation: Double = 0

    private var diameter: CGFloat { isEmphasized ? 68 : 56 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isEmphasized {
                    Circle()
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 6)
                        .frame(width: diameter + 20, height: diameter + 20)
                        .blur(radius: 6)

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Theme.accent.opacity(0.1), Theme.accent,
                                    Theme.accent.opacity(0.1), Theme.accent,
                                    Theme.accent.opacity(0.1)
                                ],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: diameter + 12, height: diameter + 12)
                        .rotationEffect(.degrees(ringRotation))
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
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                ringRotation = 360
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
