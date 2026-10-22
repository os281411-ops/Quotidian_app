import SwiftUI

/// Bookclub → + → Join with Invite Code. Shows which club the code is for
/// before joining. Private clubs need Premium.
struct JoinWithCodeView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var paywall: PaywallPresenter
    @Environment(\.dismiss) private var dismiss

    /// Called with the club once joined (or already a member), so it can be opened.
    let onJoined: (BookClub) -> Void

    @State private var code = ""
    @State private var preview: InvitePreview?
    @State private var isChecking = false
    @FocusState private var isFocused: Bool

    private var needsPremium: Bool {
        (preview?.isPrivate ?? false) && !(preview?.alreadyMember ?? false) && !subscriptions.isSubscribed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Ask a club's owner for its 8-character invite code.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)

                        TextField("", text: $code, prompt: Text("e.g. 7F3A9C21").foregroundStyle(Theme.textSecondary.opacity(0.5)))
                            .font(.system(size: 26, weight: .semibold, design: .monospaced))
                            .tracking(4)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textPrimary)
                            .tint(Theme.accent)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
                            .onChange(of: code) { _, newValue in
                                let cleaned = InvitePreview.normalize(newValue)
                                if cleaned != newValue { code = cleaned }
                                preview = nil
                                clubs.errorMessage = nil
                                if cleaned.count == 8 { Task { await check() } }
                            }

                        if isChecking {
                            ProgressView().tint(Theme.accent).frame(maxWidth: .infinity)
                        }

                        CommunityErrorText(message: clubs.errorMessage)

                        if let preview {
                            previewCard(preview)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Join with Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear {
            clubs.errorMessage = nil
            isFocused = true
        }
    }

    private func previewCard(_ preview: InvitePreview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(preview.name)
                .font(Theme.Font.serif(22, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 14) {
                Label(preview.isPrivate ? "Private" : "Public",
                      systemImage: preview.isPrivate ? "lock.fill" : "globe")
                Label("\(preview.memberCount) \(preview.memberCount == 1 ? "member" : "members")",
                      systemImage: "person.2")
            }
            .font(.caption.weight(.semibold))
            .trackedCaps(1)
            .foregroundStyle(Theme.textSecondary)

            if preview.alreadyMember {
                CommunityPrimaryButton(title: "Open Club") { join() }
            } else if needsPremium {
                Text("Private clubs are part of Premium.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                CommunityPrimaryButton(title: "Unlock with Premium") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        paywall.present(.bookclub)
                    }
                }
            } else {
                CommunityPrimaryButton(title: "Join Club", isWorking: clubs.isWorking) { join() }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
    }

    private func check() async {
        let current = code
        isChecking = true
        defer { isChecking = false }
        let found = await clubs.previewInvite(current)
        guard current == code else { return }
        preview = found
        if found != nil { isFocused = false }
    }

    private func join() {
        guard let userID = auth.userID else { return }
        Task {
            if let club = await clubs.joinWithInvite(code, userID: userID) {
                dismiss()
                onJoined(club)
            }
        }
    }
}
