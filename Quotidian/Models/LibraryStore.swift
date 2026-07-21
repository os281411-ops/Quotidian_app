import Combine
import Foundation
import SwiftUI

struct SavedQuote: Identifiable, Codable {
    var id: String { quote.id }
    let quote: Quote
    let dateSaved: Date
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var savedQuotes: [SavedQuote] = []

    private let defaults: UserDefaults
    private let storageKey = "library.savedQuotes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isSaved(_ quote: Quote) -> Bool {
        savedQuotes.contains { $0.quote.id == quote.id }
    }

    func toggle(_ quote: Quote) {
        if isSaved(quote) {
            savedQuotes.removeAll { $0.quote.id == quote.id }
        } else {
            savedQuotes.insert(SavedQuote(quote: quote, dateSaved: Date()), at: 0)
        }
        persist()
    }

    func remove(_ quote: Quote) {
        savedQuotes.removeAll { $0.quote.id == quote.id }
        persist()
    }

    /// Re-inserts a previously removed quote, used to undo an accidental removal.
    func restore(_ saved: SavedQuote, at index: Int) {
        guard !isSaved(saved.quote) else { return }
        let clampedIndex = min(max(index, 0), savedQuotes.count)
        savedQuotes.insert(saved, at: clampedIndex)
        persist()
    }

    func remove(at offsets: IndexSet) {
        savedQuotes.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedQuote].self, from: data) else { return }
        savedQuotes = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(savedQuotes) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
