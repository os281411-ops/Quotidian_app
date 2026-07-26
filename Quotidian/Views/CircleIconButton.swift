import SwiftUI

struct CircleIconButtonLabel: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    var isEmphasized: Bool = false

    private var diameter: CGFloat { isEmphasized ? 68 : 56 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(isActive || isEmphasized ? Theme.accent : Theme.divider, lineWidth: isEmphasized ? 1.5 : 1)
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
