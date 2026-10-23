import Foundation
import Supabase

/// A row from the shared `books` table. Books are added the first time
/// someone picks them from search, then reused by everyone.
nonisolated struct Book: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let author: String?
    let isbn13: String?
    let openLibraryID: String?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, author, isbn13
        case openLibraryID = "open_library_id"
        case coverURL = "cover_url"
    }

    /// Columns to request whenever a book is embedded in another query.
    static let columns = "id, title, author, isbn13, open_library_id, cover_url"

    var cover: URL? { coverURL.flatMap(URL.init(string:)) }

    /// Bookshop.org link that credits Quotidian's affiliate account.
    var bookshopURL: URL {
        BookshopAffiliate.url(isbn13: isbn13, title: title, author: author)
    }
}

extension BookshopAffiliate {
    /// Same rules as `Quote.purchaseURL`: Bookshop.org only credits affiliates
    /// through its deep-link format (bookshop.org/a/{id}/{isbn}), so use it
    /// whenever there's an ISBN, and fall back to a plain search otherwise.
    nonisolated static func url(isbn13: String?, title: String, author: String?) -> URL {
        if let id, let isbn13 {
            if let url = URL(string: "https://bookshop.org/a/\(id)/\(isbn13)") { return url }
        }
        var components = URLComponents(string: "https://bookshop.org/search")!
        components.queryItems = [
            URLQueryItem(name: "keywords", value: [title, author].compactMap { $0 }.joined(separator: " "))
        ]
        return components.url ?? URL(string: "https://bookshop.org")!
    }
}

// MARK: - Open Library search

/// A book found on Open Library, before it's saved to the `books` table.
nonisolated struct BookSearchResult: Hashable, Identifiable, Sendable {
    let openLibraryID: String
    let title: String
    let author: String?
    let year: Int?
    let coverID: Int?
    let isbn13: String?

    var id: String { openLibraryID }

    var coverURL: URL? {
        coverID.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") }
    }
}

/// Searches Open Library's free catalogue (no key needed) and saves picks.
enum BookSearch {
    private nonisolated struct Response: Decodable {
        let docs: [Doc]
    }

    private nonisolated struct Doc: Decodable {
        let key: String
        let title: String?
        let author_name: [String]?
        let first_publish_year: Int?
        let cover_i: Int?
        let isbn: [String]?
    }

    nonisolated static func search(_ query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,cover_i,isbn"),
            URLQueryItem(name: "limit", value: "20"),
        ]
        var request = URLRequest(url: components.url!)
        // Open Library asks apps to identify themselves.
        request.setValue("Quotidian/1.0 (iOS book club app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)

        return response.docs.compactMap { doc in
            guard let title = doc.title, !title.isEmpty else { return nil }
            return BookSearchResult(
                openLibraryID: doc.key.replacingOccurrences(of: "/works/", with: ""),
                title: title,
                author: doc.author_name?.first,
                year: doc.first_publish_year,
                coverID: doc.cover_i,
                isbn13: doc.isbn?.first(where: isBookshopISBN)
            )
        }
    }

    /// Bookshop.org deep links need a 13-digit ISBN starting 978 or 979.
    private nonisolated static func isBookshopISBN(_ isbn: String) -> Bool {
        isbn.count == 13
            && isbn.allSatisfy(\.isNumber)
            && (isbn.hasPrefix("978") || isbn.hasPrefix("979"))
    }

    private nonisolated struct NewBook: Encodable {
        let title: String
        let author: String?
        let isbn13: String?
        let openLibraryID: String
        let coverURL: String?

        enum CodingKeys: String, CodingKey {
            case title, author, isbn13
            case openLibraryID = "open_library_id"
            case coverURL = "cover_url"
        }
    }

    /// Returns the shared `books` row for a search result, adding it if it's new.
    @MainActor
    static func save(_ result: BookSearchResult) async throws -> Book {
        if let existing = try await findExisting(result) { return existing }

        do {
            return try await supabase
                .from("books")
                .insert(
                    NewBook(
                        title: String(result.title.prefix(300)),
                        author: result.author.map { String($0.prefix(200)) },
                        isbn13: result.isbn13,
                        openLibraryID: result.openLibraryID,
                        coverURL: result.coverURL?.absoluteString
                    ),
                    returning: .representation
                )
                .select(Book.columns)
                .single()
                .execute()
                .value
        } catch {
            // Someone else may have added the same book a moment ago.
            if let existing = try await findExisting(result) { return existing }
            throw error
        }
    }

    private nonisolated struct NewQuoteBook: Encodable {
        let title: String
        let author: String?
        let isbn13: String?
    }

    /// The shared `books` row for a Quotidian quote's book (matched by ISBN,
    /// or by title and author), adding it if it's new.
    @MainActor
    static func book(forQuote quote: Quote) async throws -> Book? {
        guard quote.hasBook else { return nil }

        func lookup() async throws -> Book? {
            var request = supabase.from("books").select(Book.columns)
            if let isbn = quote.isbn13 {
                request = request.eq("isbn13", value: isbn)
            } else {
                request = request.eq("title", value: quote.book).eq("author", value: quote.author)
            }
            let matches: [Book] = try await request.limit(1).execute().value
            return matches.first
        }

        if let existing = try await lookup() { return existing }
        do {
            return try await supabase
                .from("books")
                .insert(
                    NewQuoteBook(
                        title: String(quote.book.prefix(300)),
                        author: quote.author.isEmpty ? nil : String(quote.author.prefix(200)),
                        isbn13: quote.isbn13
                    ),
                    returning: .representation
                )
                .select(Book.columns)
                .single()
                .execute()
                .value
        } catch {
            if let existing = try await lookup() { return existing }
            throw error
        }
    }

    @MainActor
    private static func findExisting(_ result: BookSearchResult) async throws -> Book? {
        var filter = "open_library_id.eq.\(result.openLibraryID)"
        if let isbn = result.isbn13 { filter += ",isbn13.eq.\(isbn)" }

        let matches: [Book] = try await supabase
            .from("books")
            .select(Book.columns)
            .or(filter)
            .limit(1)
            .execute()
            .value
        return matches.first
    }
}
