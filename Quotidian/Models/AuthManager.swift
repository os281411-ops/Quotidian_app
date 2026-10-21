import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Supabase

/// Community sign-in: Sign in with Apple → Supabase session → profile.
///
/// Walks a new member through three gates before they can take part:
/// signed in, has a username, has agreed to the community guidelines.
@MainActor
final class AuthManager: ObservableObject {
    enum Phase: Equatable {
        case loading
        case signedOut
        case profileUnavailable   // signed in, but the profile couldn't be loaded (e.g. offline)
        case needsUsername
        case needsGuidelines
        case ready
    }

    @Published private(set) var profile: CommunityProfile?
    @Published private(set) var userID: UUID?
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private var hasStarted = false
    /// Apple only shares the person's name on their very first sign-in.
    private var pendingDisplayName: String?

    var phase: Phase {
        if isLoading { return .loading }
        guard userID != nil else { return .signedOut }
        guard let profile else { return .profileUnavailable }
        if profile.username == nil { return .needsUsername }
        if profile.acceptedGuidelinesAt == nil { return .needsGuidelines }
        return .ready
    }

    // MARK: - Session

    /// Follows sign-in / sign-out for the lifetime of the app. Call once.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn:
                if let session {
                    isLoading = true
                    userID = session.user.id
                    await loadProfile()
                } else {
                    clearSession()
                }
            case .signedOut, .userDeleted:
                clearSession()
            default:
                break
            }
            isLoading = false
        }
    }

    func loadProfile() async {
        guard let userID else { return }
        do {
            var loaded: CommunityProfile = try await supabase
                .from("profiles")
                .select(CommunityProfile.columns)
                .eq("id", value: userID)
                .single()
                .execute()
                .value

            if loaded.displayName == nil, let name = pendingDisplayName {
                // Not essential, so a failure here (e.g. the word filter) is ignored.
                if (try? await supabase
                    .from("profiles")
                    .update(["display_name": name])
                    .eq("id", value: userID)
                    .execute()) != nil {
                    loaded.displayName = name
                }
            }
            pendingDisplayName = nil
            profile = loaded
            errorMessage = nil
        } catch {
            profile = nil
            errorMessage = "Couldn't load your profile. Check your connection and try again."
        }
    }

    private func clearSession() {
        userID = nil
        profile = nil
    }

    // MARK: - Sign in with Apple

    /// Called from `SignInWithAppleButton`'s completion handler.
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>, rawNonce: String?) async {
        errorMessage = nil

        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return  // The person closed the sheet; nothing went wrong.
            }
            errorMessage = "Sign in with Apple didn't work. Please try again."

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let rawNonce
            else {
                errorMessage = "Sign in with Apple didn't work. Please try again."
                return
            }

            if let nameParts = credential.fullName {
                let name = PersonNameComponentsFormatter
                    .localizedString(from: nameParts, style: .default)
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { pendingDisplayName = String(name.prefix(40)) }
            }

            isWorking = true
            defer { isWorking = false }
            do {
                // The auth listener in `start()` picks up the new session and loads the profile.
                _ = try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: rawNonce
                    )
                )
            } catch {
                errorMessage = "Couldn't sign you in. Check your connection and try again."
            }
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        clearSession()
    }

    /// Permanently deletes the signed-in person's community account: their
    /// profile, posts, comments, reactions and memberships (the database
    /// cascades it). Saved quotes and streaks on this phone aren't touched.
    /// Returns true when the account was deleted.
    @discardableResult
    func deleteAccount() async -> Bool {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await supabase.rpc("delete_my_account").execute()
        } catch {
            errorMessage = "Couldn't delete your account. Check your connection and try again."
            return false
        }

        // The account no longer exists, so just clear the session on this phone.
        try? await supabase.auth.signOut(scope: .local)
        clearSession()
        return true
    }

    // MARK: - Profile setup

    /// Returns true when the username was saved.
    @discardableResult
    func setUsername(_ input: String) async -> Bool {
        let name = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard CommunityProfile.isValidUsername(name) else {
            errorMessage = "Use 3–20 lowercase letters, numbers or underscores."
            return false
        }
        return await updateProfile(["username": name])
    }

    @discardableResult
    func acceptGuidelines() async -> Bool {
        let now = ISO8601DateFormatter().string(from: Date())
        return await updateProfile(["accepted_guidelines_at": now])
    }

    /// Sets (or clears, with nil) the book shown as "Currently Reading".
    @discardableResult
    func setCurrentlyReading(_ book: Book?) async -> Bool {
        await updateProfile(CurrentlyReadingUpdate(bookID: book?.id))
    }

    private func updateProfile(_ values: some Encodable & Sendable) async -> Bool {
        guard let userID else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let updated: CommunityProfile = try await supabase
                .from("profiles")
                .update(values)
                .eq("id", value: userID)
                .select(CommunityProfile.columns)
                .single()
                .execute()
                .value
            profile = updated
            return true
        } catch let error as PostgrestError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = "Couldn't save. Check your connection and try again."
            return false
        }
    }

    /// Turns database errors into something a reader can act on.
    static func message(for error: PostgrestError) -> String {
        switch (error.code ?? "", error.hint ?? "") {
        case ("23505", _):            return "That username is taken. Try another."
        case ("23514", _):            return "Use 3–20 lowercase letters, numbers or underscores."
        case (_, "word_filter"):      return "That contains language that isn't allowed in Bookclub."
        case (_, "rate_limit"):       return "You're going a bit fast. Wait a minute and try again."
        default:                      return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Nonce

/// Sign in with Apple nonce: a random string whose SHA-256 hash goes to Apple,
/// while the original goes to Supabase, which checks they match. Stops a
/// stolen Apple token being replayed.
nonisolated enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// Sends `currently_reading_book_id`, including an explicit null to clear it.
nonisolated struct CurrentlyReadingUpdate: Encodable, Sendable {
    let bookID: UUID?

    enum CodingKeys: String, CodingKey {
        case bookID = "currently_reading_book_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookID, forKey: .bookID)
    }
}
