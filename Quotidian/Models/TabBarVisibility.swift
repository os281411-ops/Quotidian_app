import Combine
import SwiftUI

/// Lets a screen hide the floating tab bar while it's open, e.g. a club chat,
/// where the message box needs the bottom of the screen (like Messages).
@MainActor
final class TabBarVisibility: ObservableObject {
    @Published var isHidden = false
}
