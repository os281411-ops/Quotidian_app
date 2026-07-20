import SwiftUI

struct StreakBadgeView: View {
    enum Style {
        case compact   // "🔥 12"
        case full      // "🔥 12 DAY STREAK"
    }

    let streak: Int
    var style: Style = .compact

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption.weight(.bold))
                .trackedCaps(1)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().stroke(Theme.accent.opacity(0.3), lineWidth: 1))
    }

    private var label: String {
        switch style {
        case .compact: "\(streak)"
        case .full: "\(streak) day\(streak == 1 ? "" : "s") streak"
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 16) {
            StreakBadgeView(streak: 12, style: .full)
            StreakBadgeView(streak: 12, style: .compact)
        }
    }
}
