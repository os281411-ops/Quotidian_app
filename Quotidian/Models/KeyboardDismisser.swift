import UIKit

/// Tap anywhere to close the keyboard, on every screen (sheets included).
///
/// One tap recognizer sits on the app's window and watches taps alongside
/// everything else, so buttons, lists and links keep working as normal.
/// It ignores taps on text boxes themselves, and taps just above the
/// keyboard, where chat's message box and send button sit (so sending a
/// message doesn't close the keyboard).
@MainActor
final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()

    /// How far above the keyboard taps are left alone (the chat composer,
    /// including an attached book or a spoiler label, fits in this).
    private let composerZone: CGFloat = 170

    private var keyboardTop: CGFloat?
    private weak var installedWindow: UIWindow?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    /// Adds the tap recognizer to the app's window (once).
    func install() {
        guard installedWindow == nil,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) else { return }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        installedWindow = window
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        tap.view?.endEditing(true)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let screenHeight = installedWindow?.bounds.height ?? frame.maxY
        keyboardTop = frame.minY < screenHeight ? frame.minY : nil
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        keyboardTop = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let keyboardTop else { return false }

        // Tapping into a text box shouldn't close the keyboard.
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }

        // Leave the message box area just above the keyboard alone.
        let location = touch.location(in: gestureRecognizer.view)
        return location.y < keyboardTop - composerZone
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
