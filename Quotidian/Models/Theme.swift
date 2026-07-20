import SwiftUI

enum Theme {
    static let background = Color(hex: 0x000000)
    static let surface = Color(hex: 0x17171A)
    static let surfaceElevated = Color(hex: 0x1E1E22)
    static let accent = Color(hex: 0xD8A94C)
    static let accentDim = Color(hex: 0xD8A94C).opacity(0.6)
    static let textPrimary = Color(hex: 0xF4F1EA)
    static let textSecondary = Color(hex: 0x9B9B9E)
    static let divider = Color.white.opacity(0.08)

    enum Font {
        static func serif(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .serif)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    /// Small-caps-style tracked uppercase label, used throughout for meta text.
    func trackedCaps(_ spacing: CGFloat = 1.5) -> some View {
        self.textCase(.uppercase).tracking(spacing)
    }
}
