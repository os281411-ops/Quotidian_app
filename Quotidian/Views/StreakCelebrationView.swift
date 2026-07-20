import SwiftUI
import UIKit

struct StreakCelebrationView: View {
    let streak: Int
    let milestoneLabel: String?
    let onDismiss: () -> Void

    @State private var animateIn = false
    @State private var particles: [Particle] = []
    @State private var ringExpanded = false

    private var isMilestone: Bool { milestoneLabel != nil }

    private let symbols = ["✨", "🔥", "📖", "⭐️", "🎉"]
    private let milestoneSymbols = ["✨", "🔥", "📖", "⭐️", "🎉", "🏆"]

    private struct Particle: Identifiable {
        let id = UUID()
        let symbol: String
        let x: CGFloat
        let delay: Double
        let duration: Double
        let rotation: Double
    }

    var body: some View {
        ZStack {
            Color.black.opacity(animateIn ? (isMilestone ? 0.85 : 0.75) : 0)
                .ignoresSafeArea()

            if isMilestone {
                Circle()
                    .stroke(Theme.accent.opacity(0.4), lineWidth: 2)
                    .frame(width: ringExpanded ? 320 : 40, height: ringExpanded ? 320 : 40)
                    .opacity(ringExpanded ? 0 : 1)
            }

            ForEach(particles) { particle in
                Text(particle.symbol)
                    .font(.system(size: isMilestone ? 32 : 28))
                    .rotationEffect(.degrees(animateIn ? particle.rotation : 0))
                    .offset(x: particle.x, y: animateIn ? (isMilestone ? -520 : -420) : 40)
                    .opacity(animateIn ? 0 : 1)
                    .animation(.easeOut(duration: particle.duration).delay(particle.delay), value: animateIn)
            }

            VStack(spacing: 12) {
                if let milestoneLabel {
                    Text(milestoneLabel)
                        .font(.caption.weight(.bold))
                        .trackedCaps(2)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent.opacity(0.15)))
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                }

                Image(systemName: "flame.fill")
                    .font(.system(size: isMilestone ? 68 : 56))
                    .foregroundStyle(Theme.accent)
                    .scaleEffect(animateIn ? 1 : 0.2)

                Text("\(streak)")
                    .font(Theme.Font.serif(isMilestone ? 76 : 64, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .scaleEffect(animateIn ? 1 : 0.2)

                Text(streak == 1 ? "Streak Started!" : "Day Streak!")
                    .font(.subheadline.weight(.bold))
                    .trackedCaps(1.5)
                    .foregroundStyle(Theme.accent)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.surfaceElevated))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.accent.opacity(isMilestone ? 0.5 : 0.3), lineWidth: isMilestone ? 1.5 : 1))
            .scaleEffect(animateIn ? 1 : 0.6)
            .opacity(animateIn ? 1 : 0)
        }
        .onAppear {
            let count = isMilestone ? 26 : 14
            let symbolSet = isMilestone ? milestoneSymbols : symbols
            let spread: ClosedRange<CGFloat> = isMilestone ? -170...170 : -140...140

            particles = (0..<count).map { _ in
                Particle(
                    symbol: symbolSet.randomElement()!,
                    x: CGFloat.random(in: spread),
                    delay: Double.random(in: 0...0.3),
                    duration: Double.random(in: 0.9...1.6),
                    rotation: Double.random(in: -180...180)
                )
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if isMilestone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                animateIn = true
            }
            if isMilestone {
                withAnimation(.easeOut(duration: 1.1)) {
                    ringExpanded = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + (isMilestone ? 3.0 : 2.2)) {
                dismiss()
            }
        }
        .onTapGesture {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            animateIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview("Regular day") {
    StreakCelebrationView(streak: 12, milestoneLabel: nil, onDismiss: {})
}

#Preview("Milestone") {
    StreakCelebrationView(streak: 30, milestoneLabel: StreakMilestone.label(for: 30), onDismiss: {})
}
