import SwiftUI

/// Where book clubs will live. For now it confirms sign-in worked
/// (checklist phase 3 replaces the placeholder card with real clubs).
struct CommunityHomeView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                CommunityHeader(title: "Community", subtitle: "Book Clubs")

                HStack(spacing: 14) {
                    Circle()
                        .fill(Theme.surfaceElevated)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(initial)
                                .font(Theme.Font.serif(22, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = auth.profile?.displayName {
                            Text(name)
                                .font(Theme.Font.serif(17))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text("@\(auth.profile?.username ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.accentDim)
                    Text("Book clubs are on their way")
                        .font(Theme.Font.serif(20, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("You're all set. Soon you'll be able to join clubs and share passages here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .padding(.horizontal, 24)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                Button("Sign out") {
                    Task { await auth.signOut() }
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
    }

    private var initial: String {
        let source = auth.profile?.displayName ?? auth.profile?.username ?? "?"
        return String(source.prefix(1)).uppercased()
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CommunityHomeView()
    }
    .environmentObject(AuthManager())
}
