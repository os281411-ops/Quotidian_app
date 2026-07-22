import Combine
import SwiftUI

/// Publishes whether the software keyboard is currently visible, so UI (like a
/// floating tab bar) can hide itself instead of fighting the keyboard for space.
@MainActor
final class KeyboardObserver: ObservableObject {
    @Published private(set) var isVisible = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in self?.isVisible = true }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in self?.isVisible = false }
            .store(in: &cancellables)
    }
}
