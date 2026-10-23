import Foundation

/// Public links used when sharing.
enum AppLinks {
    /// Quotidian on the App Store (opens the right country's store automatically).
    static let appStore = URL(string: "https://apps.apple.com/app/id6793500120")!

    static let supportPage = URL(string: "https://os281411-ops.github.io/Quotidian_app/support.html")!
    static let privacyPolicy = URL(string: "https://os281411-ops.github.io/Quotidian_app/privacy-policy.html")!
    static let supportEmail = "quotidian.support@gmail.com"

    /// A pre-addressed email with a subject line (and app version, to help debugging).
    static func supportMail(subject: String) -> URL {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "\(subject) (Quotidian \(version))")]
        return components.url ?? URL(string: "mailto:\(supportEmail)")!
    }

    /// Added to everything shared outside the app, so people know where it came from.
    static let shareAttribution = "Shared from Quotidian, a quote a day from great books\n\(appStore.absoluteString)"
}
