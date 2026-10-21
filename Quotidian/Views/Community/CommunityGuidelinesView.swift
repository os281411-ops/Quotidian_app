import SwiftUI

/// Third step: agree to the community guidelines. App Store guideline 1.2
/// requires people to accept terms with zero tolerance for objectionable
/// content before they can post.
struct CommunityGuidelinesView: View {
    @EnvironmentObject private var auth: AuthManager

    private struct Rule: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private let rules: [Rule] = [
        Rule(icon: "text.quote", title: "Share passages, quote them fairly",
             detail: "Post quotes from books you're reading and say where they're from."),
        Rule(icon: "heart", title: "Be kind",
             detail: "Disagree with ideas, not people. No harassment, bullying or threats."),
        Rule(icon: "hand.raised", title: "No hate",
             detail: "No slurs, hate speech or attacks on anyone for who they are."),
        Rule(icon: "eye.slash", title: "Keep it clean",
             detail: "No sexual content, graphic violence, spam or advertising."),
        Rule(icon: "flag", title: "Report what breaks the rules",
             detail: "Tap Report on any post, comment or reader. Reports are reviewed within 24 hours."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                CommunityHeader(title: "House Rules", subtitle: "Step 2 of 2")

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(rules) { rule in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: rule.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.title)
                                    .font(Theme.Font.serif(17, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(rule.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(22)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                Text("There's zero tolerance for objectionable content or abusive readers. Posts that break these rules are removed, and accounts that break them are suspended.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                CommunityErrorText(message: auth.errorMessage)

                CommunityPrimaryButton(title: "I Agree", isWorking: auth.isWorking) {
                    Task { await auth.acceptGuidelines() }
                }

                Button("Sign out") {
                    Task { await auth.signOut() }
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CommunityGuidelinesView()
    }
    .environmentObject(AuthManager())
}
