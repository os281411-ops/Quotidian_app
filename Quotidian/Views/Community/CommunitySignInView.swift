import AuthenticationServices
import SwiftUI

/// First screen of the Community tab for anyone not signed in.
struct CommunitySignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var currentNonce: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                CommunityHeader(title: "Community", subtitle: "Book Clubs")

                VStack(spacing: 18) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)

                    Text("Read together.")
                        .font(Theme.Font.serif(28, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Join book clubs, share the passages that stay with you, and talk them through with other readers.")
                        .font(Theme.Font.serif(16))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AppleSignInNonce.random()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName]
                        request.nonce = AppleSignInNonce.sha256(nonce)
                    } onCompletion: { result in
                        Task { await auth.handleAppleSignIn(result, rawNonce: currentNonce) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .disabled(auth.isWorking)
                    .overlay {
                        if auth.isWorking {
                            Capsule().fill(Theme.surfaceElevated.opacity(0.9))
                            ProgressView().tint(Theme.textPrimary)
                        }
                    }

                    CommunityErrorText(message: auth.errorMessage)

                    Text("Your Apple ID just creates your account. We don't ask for your email, and other readers only see the username you choose.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        CommunitySignInView()
    }
    .environmentObject(AuthManager())
}
