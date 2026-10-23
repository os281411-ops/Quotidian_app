import Foundation

/// Public links used when sharing.
enum AppLinks {
    /// Quotidian on the App Store (opens the right country's store automatically).
    static let appStore = URL(string: "https://apps.apple.com/app/id6793500120")!

    /// Added to everything shared outside the app, so people know where it came from.
    static let shareAttribution = "Shared from Quotidian, a quote a day from great books\n\(appStore.absoluteString)"
}
