import SwiftUI

struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 12)

            Button(action: onUndo) {
                Text("UNDO")
                    .font(.subheadline.weight(.bold))
                    .trackedCaps(1)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        UndoToast(message: "Removed from Library", onUndo: {})
            .padding()
    }
}
