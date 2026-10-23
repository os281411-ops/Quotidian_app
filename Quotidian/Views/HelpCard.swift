import SwiftUI
import UIKit

/// Profile → Help & Feedback: email support, the help page, privacy policy.
struct HelpCard: View {
    @State private var copiedEmail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Help & Feedback")
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)

            Link(destination: AppLinks.supportMail(subject: "Quotidian feedback")) {
                row("Email Support", icon: "envelope")
            }
            Divider().overlay(Theme.divider)
            Link(destination: AppLinks.supportPage) {
                row("Help & FAQ", icon: "questionmark.circle", external: true)
            }
            Divider().overlay(Theme.divider)
            Link(destination: AppLinks.privacyPolicy) {
                row("Privacy Policy", icon: "hand.raised", external: true)
            }

            // For when no Mail app is set up (e.g. the Simulator).
            Button {
                UIPasteboard.general.string = AppLinks.supportEmail
                copiedEmail = true
            } label: {
                Text(copiedEmail ? "Copied \(AppLinks.supportEmail)" : AppLinks.supportEmail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func row(_ title: String, icon: String, external: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: external ? "arrow.up.right" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.body)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
