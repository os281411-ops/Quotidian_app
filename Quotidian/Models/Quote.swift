import Foundation

struct Quote: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let author: String
    let book: String
    let year: String
    let about: String
    /// ISBN-13 for the standard edition, used to build a Bookshop.org affiliate deep link.
    let isbn13: String?
}

extension Quote {
    /// False for quotes that aren't drawn from a specific book (e.g. standalone
    /// inspirational quotes) — used to hide book/purchase UI for those entries.
    var hasBook: Bool { !book.isEmpty }

    var shareText: String {
        hasBook ? "\"\(text)\"\n— \(author), \(book)" : "\"\(text)\"\n— \(author)"
    }

    /// Bookshop.org attributes affiliate credit only through its documented link
    /// formats (e.g. bookshop.org/a/{affiliateID}/{isbn}), not plain search URLs.
    /// So we use the affiliate deep link whenever both an ID and ISBN are known,
    /// and fall back to a plain search link otherwise.
    var purchaseURL: URL {
        if let affiliateID = BookshopAffiliate.id, let isbn13 {
            return URL(string: "https://bookshop.org/a/\(affiliateID)/\(isbn13)") ?? searchURL
        }
        return searchURL
    }

    private var searchURL: URL {
        var components = URLComponents(string: "https://bookshop.org/search")!
        components.queryItems = [URLQueryItem(name: "keywords", value: "\(book) \(author)")]
        return components.url ?? URL(string: "https://bookshop.org")!
    }
}
