import SwiftUI

struct PurchaseButton: View {
    let url: URL
    var title: String = "Purchase Book"

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: "bag")
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .trackedCaps(1.5)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        PurchaseButton(url: URL(string: "https://bookshop.org")!)
            .padding()
    }
}
