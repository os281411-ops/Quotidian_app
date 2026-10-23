import Combine
import Foundation

/// How a quote made someone feel. Picked from the Reflect card on Today.
enum ReflectionMood: String, Codable, CaseIterable, Identifiable {
    case inspired, moved, calm, thoughtful, challenged, notForMe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inspired: "Inspired"
        case .moved: "Moved"
        case .calm: "Calm"
        case .thoughtful: "Thoughtful"
        case .challenged: "Challenged"
        case .notForMe: "Not for me"
        }
    }

    var symbol: String {
        switch self {
        case .inspired: "sparkles"
        case .moved: "heart"
        case .calm: "leaf"
        case .thoughtful: "lightbulb"
        case .challenged: "bolt"
        case .notForMe: "hand.thumbsdown"
        }
    }

    /// Filled icon for the selected state ("sparkles" has no filled version).
    var selectedSymbol: String {
        self == .inspired ? symbol : symbol + ".fill"
    }
}

/// A reader's private response to one quote.
struct Reflection: Codable, Equatable {
    var mood: ReflectionMood?
    var note: String
    var updatedAt: Date

    var isEmpty: Bool {
        mood == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Reflections are kept only on this device (like the Library and streak):
/// no account, nothing sent anywhere.
@MainActor
final class ReflectionStore: ObservableObject {
    static let noteLimit = 500

    @Published private(set) var reflections: [String: Reflection] = [:]

    private let defaults: UserDefaults
    private let storageKey = "reflections.byQuote"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func reflection(for quote: Quote) -> Reflection? {
        reflections[quote.id]
    }

    func setMood(_ mood: ReflectionMood?, for quote: Quote) {
        update(quote) { $0.mood = mood }
    }

    func setNote(_ note: String, for quote: Quote) {
        update(quote) { $0.note = String(note.prefix(Self.noteLimit)) }
    }

    func clear(for quote: Quote) {
        reflections[quote.id] = nil
        persist()
    }

    private func update(_ quote: Quote, _ change: (inout Reflection) -> Void) {
        var reflection = reflections[quote.id] ?? Reflection(mood: nil, note: "", updatedAt: Date())
        change(&reflection)
        reflection.updatedAt = Date()
        reflections[quote.id] = reflection.isEmpty ? nil : reflection
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Reflection].self, from: data) else { return }
        reflections = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(reflections) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
