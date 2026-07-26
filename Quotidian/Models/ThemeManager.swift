import Combine
import SwiftUI

/// Premium perk: curated accent color palettes. `Theme.accent` reads
/// `AccentPalette.current` directly so every existing call site picks up the
/// selection without threading a color through the view hierarchy.
enum AccentPalette: String, CaseIterable, Identifiable {
    case gold, rose, sage, azure

    static var current: AccentPalette = .gold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gold: "Classic Gold"
        case .rose: "Rose"
        case .sage: "Sage"
        case .azure: "Azure"
        }
    }

    var color: Color {
        switch self {
        case .gold: Color(hex: 0xD8A94C)
        case .rose: Color(hex: 0xF27171)
        case .sage: Color(hex: 0x9CCD96)
        case .azure: Color(hex: 0x5CAEF2)
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published var palette: AccentPalette {
        didSet {
            AccentPalette.current = palette
            defaults.set(palette.rawValue, forKey: key)
        }
    }

    private let defaults: UserDefaults
    private let key = "theme.palette"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: key).flatMap(AccentPalette.init(rawValue:)) ?? .gold
        palette = saved
        AccentPalette.current = saved
    }

    /// Non-subscribers are held to the default palette even if they picked
    /// another one while subscribed and later lapsed.
    func enforceFreeTier(isSubscribed: Bool) {
        guard !isSubscribed, palette != .gold else { return }
        palette = .gold
    }
}
