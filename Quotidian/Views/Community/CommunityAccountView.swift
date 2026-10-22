import SwiftUI

/// Your community account: who you're signed in as, sign out, delete account.
struct CommunityAccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var showBookPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        profileCard
                        currentlyReadingCard
                        if auth.isAdmin {
                            moderationLink
                        }
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
        .presentationDetents([.large])
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(title: "Currently Reading") { book in
                Task { await auth.setCurrentlyReading(book) }
            }
        }
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

    private var currentlyReadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Currently Reading")
                    .font(.caption.weight(.semibold))
                    .trackedCaps(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if auth.profile?.currentlyReading != nil {
                    Menu {
                        Button("Change Book") { showBookPicker = true }
                        Button("Remove", role: .destructive) {
                            Task { await auth.setCurrentlyReading(nil) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel("Change currently reading")
                }
            }

            if let book = auth.profile?.currentlyReading {
                BookCard(book: book)
            } else {
                Button { showBookPicker = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 40, height: 56)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add what you're reading")
                                .font(Theme.Font.serif(16))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Other club members see it on your profile.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    /// Only shown to admins (accounts in `app_admins`).
    private var moderationLink: some View {
        NavigationLink {
            ModerationView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Reports")
                        .foregroundStyle(Theme.textPrimary)
                    Text("Admin only")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
