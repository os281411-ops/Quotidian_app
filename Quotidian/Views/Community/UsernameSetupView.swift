import SwiftUI

/// Second step after signing in: choose the name other readers will see.
struct UsernameSetupView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var username = ""
    @FocusState private var isFocused: Bool

    private var isValid: Bool { CommunityProfile.isValidUsername(username) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                CommunityHeader(title: "Welcome", subtitle: "Step 1 of 2")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick a username")
                        .font(Theme.Font.serif(22, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("This is how other readers will see you in book clubs.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 2) {
                        Text("@")
                            .foregroundStyle(Theme.textSecondary)
                        TextField("", text: $username, prompt: Text("yourname").foregroundStyle(Theme.textSecondary.opacity(0.5)))
                            .foregroundStyle(Theme.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.done)
                            .focused($isFocused)
                            .onSubmit(save)
                    }
                    .font(Theme.Font.serif(20))
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isFocused ? Theme.accent.opacity(0.6) : Theme.divider, lineWidth: 1)
                    )
                    .onChange(of: username) { _, newValue in
                        // Keep only what the database accepts, as the person types.
                        let cleaned = String(
                            newValue.lowercased()
                                .filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
                                .prefix(20)
                        )
                        if cleaned != newValue { username = cleaned }
                    }

                    Text("3–20 characters: letters, numbers and underscores.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)

                    CommunityErrorText(message: auth.errorMessage)
                }

                CommunityPrimaryButton(
                    title: "Continue",
                    isWorking: auth.isWorking,
                    isEnabled: isValid,
                    action: save
                )

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
        .scrollDismissesKeyboard(.interactively)
        .onAppear { isFocused = true }
    }

    private func save() {
        guard isValid else { return }
        Task {
            if await auth.setUsername(username) {
                isFocused = false
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        UsernameSetupView()
    }
    .environmentObject(AuthManager())
}
