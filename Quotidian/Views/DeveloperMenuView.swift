#if DEBUG
import Supabase
import SwiftUI
import UIKit

/// Developer tools. Everything in this file only exists in Debug builds
/// ("Quotidian Dev", what Xcode's Run button builds). It's never in the
/// App Store version, because Archive uses the Release configuration.

/// Card shown at the bottom of the Profile tab in Debug builds.
struct DeveloperMenuButton: View {
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer Menu")
                        .font(Theme.Font.serif(17))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Only in Quotidian Dev builds")
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
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            DeveloperMenuView()
        }
    }
}

struct DeveloperMenuView: View {
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var paywall: PaywallPresenter
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var notice: String?
    @AppStorage("debug.useLiveDatabase") private var useLiveDatabase = false

    var body: some View {
        NavigationStack {
            Form {
                Section("This Build") {
                    row("App", Bundle.main.bundleIdentifier ?? "?")
                    row("Version", "\(appVersion) (\(buildNumber))")
                }

                Section {
                    row("Connected to", SupabaseConfig.isDevDatabase ? "DEV database" : "LIVE database")
                    row("Address", SupabaseConfig.url.host() ?? "?")
                    Toggle("Use Live Database", isOn: $useLiveDatabase)
                        .onChange(of: useLiveDatabase) { _, _ in
                            notice = "Quit and reopen the app to switch databases."
                        }
                } header: {
                    Text("Database")
                } footer: {
                    Text("The dev app normally uses the DEV database so testing never touches real users. Turn this on to look at live data; anything you do then is real.")
                }

                Section {
                    Picker("Premium", selection: premiumBinding) {
                        Text("Real (StoreKit)").tag(PremiumMode.real)
                        Text("Force On").tag(PremiumMode.on)
                        Text("Force Off").tag(PremiumMode.off)
                    }
                    row("Premium right now", subscriptions.isSubscribed ? "Yes" : "No")
                    Button("Show Paywall") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            paywall.present(.general)
                        }
                    }
                } header: {
                    Text("Premium")
                } footer: {
                    Text("Force On unlocks every Premium feature without buying, so you can test themes, the archive and Premium Bookclub features.")
                }

                Section {
                    if let userID = auth.userID {
                        row("Signed in as", "@\(auth.profile?.username ?? "no username")")
                        Button("Copy My User ID") {
                            UIPasteboard.general.string = userID.uuidString.lowercased()
                            notice = "User ID copied."
                        }
                        Button("Sign Out of Bookclub", role: .destructive) {
                            Task { await auth.signOut() }
                        }
                    } else {
                        Text("Not signed in to Bookclub.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Bookclub")
                } footer: {
                    Text("Your user ID is what you'd paste into Supabase to make yourself an admin (for the moderation view).")
                }

                Section {
                    Button("Show Onboarding Paywall Again") {
                        UserDefaults.standard.removeObject(forKey: "onboarding.paywallShown")
                        notice = "Done. Quit and reopen the app to see it."
                    }
                    Button("Reset Streak", role: .destructive) {
                        for key in ["streak.lastVisitDate", "streak.current", "streak.longest",
                                    "streak.freeze.month", "streak.freeze.count"] {
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                        notice = "Streak reset. Quit and reopen the app to see it."
                    }
                    Button("Clear Library", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "library.savedQuotes")
                        notice = "Library cleared. Quit and reopen the app to see it."
                    }
                } header: {
                    Text("Reset")
                } footer: {
                    Text("These only affect this dev app. The App Store version on the same phone keeps its own data.")
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Helpers

    private enum PremiumMode: Hashable { case real, on, off }

    private var premiumBinding: Binding<PremiumMode> {
        Binding(
            get: {
                switch subscriptions.debugPremiumOverride {
                case nil: .real
                case true?: .on
                case false?: .off
                }
            },
            set: { mode in
                switch mode {
                case .real: subscriptions.debugPremiumOverride = nil
                case .on: subscriptions.debugPremiumOverride = true
                case .off: subscriptions.debugPremiumOverride = false
                }
            }
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
#endif
