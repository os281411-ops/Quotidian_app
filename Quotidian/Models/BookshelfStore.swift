import Combine
import Foundation

/// A book on your shelf. Kept only on this iPhone (like the Library).
nonisolated struct ShelfBook: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var author: String?
    var year: Int?
    /// The edition used for the Bookshop.org link (may be updated later).
    var isbn13: String?
    var openLibraryID: String?
    var coverID: Int?
    let addedAt: Date
    /// Your rating, 1–5 stars (nil = not rated).
    var rating: Int?
    /// Your private thoughts on the book.
    var thoughts: String?

    /// Front cover for the shelf grid.
    var coverURL: URL? { cover(size: "M") }
    /// Bigger cover for the detail page.
    var largeCoverURL: URL? { cover(size: "L") }

    private func cover(size: String) -> URL? {
        if let coverID {
            return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-\(size).jpg")
        }
        if let isbn13 {
            // default=false makes Open Library return "not found" instead of a blank image.
            return URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn13)-\(size).jpg?default=false")
        }
        return nil
    }

    /// Same shape as a club book, so the Bookshop.org helpers work on it.
    var asBook: Book {
        Book(id: id, title: title, author: author, isbn13: isbn13, openLibraryID: openLibraryID, coverURL: coverURL?.absoluteString)
    }
}

/// Your bookshelf: books you've scanned or searched for, newest first.
@MainActor
final class BookshelfStore: ObservableObject {
    @Published fileprivate(set) var books: [ShelfBook] = []

    private let defaults: UserDefaults
    private let storageKey = "bookshelf.books"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([ShelfBook].self, from: data) {
            books = saved
        }
    }

    /// Already on the shelf (same Open Library work, or same ISBN)?
    func contains(_ result: BookSearchResult) -> Bool {
        books.contains { book in
            book.openLibraryID == result.openLibraryID
                || (book.isbn13 != nil && result.isbnCandidates.contains(book.isbn13!))
        }
    }

    /// Adds a book found by search or scan. Returns false if it's already there.
    @discardableResult
    func add(_ result: BookSearchResult) -> Bool {
        guard !contains(result) else { return false }
        let book = ShelfBook(
            id: UUID(),
            title: result.title,
            author: result.author,
            year: result.year,
            isbn13: result.isbnCandidates.first,
            openLibraryID: result.openLibraryID,
            coverID: result.coverID,
            addedAt: Date(),
            rating: nil,
            thoughts: nil
        )
        books.insert(book, at: 0)
        save()

        // Swap in an edition Bookshop.org actually stocks, in the background.
        let candidates = result.isbnCandidates
        Task {
            guard candidates.count > 1,
                  let stocked = await BookshopAffiliate.firstStocked(candidates),
                  stocked != book.isbn13,
                  let index = books.firstIndex(where: { $0.id == book.id }) else { return }
            books[index].isbn13 = stocked
            save()
        }
        return true
    }

    static let thoughtsLimit = 2000

    /// Sets (or clears, with nil) your star rating.
    func setRating(_ rating: Int?, for book: ShelfBook) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].rating = rating.map { min(max($0, 1), 5) }
        save()
    }

    func setThoughts(_ thoughts: String, for book: ShelfBook) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let trimmed = thoughts.trimmingCharacters(in: .whitespacesAndNewlines)
        books[index].thoughts = trimmed.isEmpty ? nil : String(thoughts.prefix(Self.thoughtsLimit))
        save()
    }

    func remove(_ book: ShelfBook) {
        books.removeAll { $0.id == book.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        defaults.set(data, forKey: storageKey)
    }

    #if DEBUG
    fileprivate func saveForDebug() { save() }
    #endif
}

#if DEBUG
extension BookshelfStore {
    /// Developer Menu: fills the shelf with well-known books (for screenshots).
    func fillWithSampleBooks() {
        let samples: [(String, String, Int, String, Int?, String?)] = [
            ("The Great Gatsby", "F. Scott Fitzgerald", 1925, "9780743273565", 5, "The green light at the end of the dock will stay with me for a long time. Short, sad and perfect."),
            ("Pride and Prejudice", "Jane Austen", 1813, "9780143138730", 5, nil),
            ("1984", "George Orwell", 1949, "9780451524935", 4, nil),
            ("To Kill a Mockingbird", "Harper Lee", 1960, "9780060935467", 5, nil),
            ("Jane Eyre", "Charlotte Brontë", 1847, "9780141441146", 4, nil),
            ("The Book Thief", "Markus Zusak", 2005, "9780375842207", 5, nil),
            ("Frankenstein", "Mary Shelley", 1818, "9780141439471", 4, nil),
            ("The Hunger Games", "Suzanne Collins", 2008, "9780439023528", 4, nil),
            ("Brave New World", "Aldous Huxley", 1932, "9780060850524", 3, nil),
            ("Educated", "Tara Westover", 2018, "9780399590504", 5, nil),
            ("The Catcher in the Rye", "J.D. Salinger", 1951, "9780316769488", 3, nil),
            ("Life of Pi", "Yann Martel", 2001, "9780156027328", 4, nil),
            ("The Kite Runner", "Khaled Hosseini", 2003, "9781594631931", 5, nil),
            ("Fahrenheit 451", "Ray Bradbury", 1953, "9781451673319", 4, nil),
            ("Little Women", "Louisa May Alcott", 1868, "9780147514011", nil, nil),
            ("Rebecca", "Daphne du Maurier", 1938, "9780316575201", 4, nil),
        ]
        let now = Date()
        books = samples.enumerated().map { index, item in
            ShelfBook(
                id: UUID(),
                title: item.0,
                author: item.1,
                year: item.2,
                isbn13: item.3,
                openLibraryID: nil,
                coverID: nil,
                addedAt: now.addingTimeInterval(TimeInterval(-index * 86_400 * 3)),
                rating: item.4,
                thoughts: item.5
            )
        }
        saveForDebug()
    }

    func clearForDebug() {
        books = []
        saveForDebug()
    }
}
#endif
