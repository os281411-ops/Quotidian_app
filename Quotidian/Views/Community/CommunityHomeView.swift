import SwiftUI

/// Where book clubs will live. For now it confirms sign-in worked
/// (checklist phase 3 replaces the placeholder card with real clubs).
struct CommunityHomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmingDelete = false

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

                accountCard
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
        .alert("Delete your account?", isPresented: $confirmingDelete) {
            Button("Delete Account", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your username, posts, comments and reactions. Your saved quotes and streak on this phone stay as they are. This can't be undone.")
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account")
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 12)

            Button {
                Task { await auth.signOut() }
            } label: {
                accountRow("Sign Out", icon: "rectangle.portrait.and.arrow.right", color: Theme.textPrimary)
            }

            Divider().overlay(Theme.divider)

            Button {
                confirmingDelete = true
            } label: {
                accountRow("Delete Account", icon: "trash", color: Color(hex: 0xFF6B6B))
            }
            .disabled(auth.isWorking)

            CommunityErrorText(message: auth.errorMessage)
                .padding(.top, 8)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func accountRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
            Text(title)
            Spacer()
            if auth.isWorking && title == "Delete Account" {
                ProgressView().tint(Theme.textSecondary)
            }
        }
        .font(.body)
        .foregroundStyle(color)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
