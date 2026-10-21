import SwiftUI

/// The Community tab. Shows whichever step the reader is at:
/// sign in → pick a username → agree to the guidelines → book clubs.
struct CommunityView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch auth.phase {
            case .loading:
                ProgressView().tint(Theme.accent)
            case .signedOut:
                CommunitySignInView()
            case .profileUnavailable:
                CommunityRetryView()
            case .needsUsername:
                UsernameSetupView()
            case .needsGuidelines:
                CommunityGuidelinesView()
            case .ready:
                CommunityHomeView()
            }
        }
        .animation(.easeOut(duration: 0.25), value: auth.phase)
    }
}

// MARK: - Shared pieces

/// Page title in the same style as the Profile tab.
struct CommunityHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Font.serif(34, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .trackedCaps(1.5)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

/// Full-width accent button used for the main action on each step.
struct CommunityPrimaryButton: View {
    let title: String
    var isWorking = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.body.weight(.semibold))
                    .opacity(isWorking ? 0 : 1)
                if isWorking {
                    ProgressView().tint(Theme.background)
                }
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(isEnabled ? Theme.accent : Theme.accent.opacity(0.35)))
        }
        .disabled(!isEnabled || isWorking)
    }
}

/// Error line shown under a form.
struct CommunityErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color(hex: 0xFF6B6B))
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }
}

/// Signed in, but the profile didn't load (usually no connection).
struct CommunityRetryView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textSecondary)
            Text(auth.errorMessage ?? "Couldn't load your profile.")
                .font(Theme.Font.serif(17))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            CommunityPrimaryButton(title: "Try Again", isWorking: auth.isWorking) {
                Task { await auth.loadProfile() }
            }
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    CommunityView()
        .environmentObject(AuthManager())
}
