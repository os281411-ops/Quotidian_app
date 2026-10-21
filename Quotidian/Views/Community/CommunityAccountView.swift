import SwiftUI

/// Your community account: who you're signed in as, sign out, delete account.
struct CommunityAccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        profileCard
                        actionsCard
                        CommunityErrorText(message: auth.errorMessage)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Delete your account?", isPresented: $confirmingDelete) {
            Button("Delete Account", role: .destructive) {
                Task {
                    if await auth.deleteAccount() { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your username, posts, comments and reactions. Clubs you started stay open for their members. Your saved quotes and streak on this phone stay as they are. This can't be undone.")
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.surfaceElevated)
                .frame(width: 52, height: 52)
                .overlay(
                    Text(initial)
                        .font(Theme.Font.serif(22, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                if let name = auth.profile?.displayName {
                    Text(name)
                        .font(Theme.Font.serif(18))
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
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button {
                Task {
                    await auth.signOut()
                    dismiss()
                }
            } label: {
                row("Sign Out", icon: "rectangle.portrait.and.arrow.right", color: Theme.textPrimary)
            }

            Divider().overlay(Theme.divider)

            Button {
                confirmingDelete = true
            } label: {
                row("Delete Account", icon: "trash", color: Color(hex: 0xFF6B6B), showsProgress: auth.isWorking)
            }
            .disabled(auth.isWorking)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func row(_ title: String, icon: String, color: Color, showsProgress: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
            Text(title)
            Spacer()
            if showsProgress {
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
    CommunityAccountView()
        .environmentObject(AuthManager())
}
