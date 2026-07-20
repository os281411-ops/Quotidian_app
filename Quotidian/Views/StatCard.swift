import SwiftUI

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(Theme.Font.serif(30, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .trackedCaps(1.2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack {
            StatCard(value: "12", label: "Longest Streak")
            StatCard(value: "8", label: "Saved")
        }
        .padding()
    }
}
