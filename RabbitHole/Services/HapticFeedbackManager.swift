import UIKit

/// Wraps UIKit feedback generators, which do not depend on the system haptic
/// pattern library (`hapticpatternlibrary.plist`) and work gracefully on
/// devices and simulators that lack haptic hardware.
@MainActor
final class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()

    private init() {}

    func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
