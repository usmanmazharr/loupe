import UIKit

/// Detects shake gestures by swizzling `UIApplication.sendEvent(_:)`.
///
/// Unlike swizzling `UIWindow.motionEnded`, this is safe because:
/// - `UIApplication` defines `sendEvent` itself (not inherited from a superclass
///   shared with other framework types).
/// - The swizzle affects only the single `UIApplication` instance.
/// - No `_UIHostingView` or other responder is touched.
public enum ShakeDetector {

    public static let shakeNotification = Notification.Name("com.loupe.ShakeDetected")

    private static var isEnabled = false
    private static var lastShakeDate = Date.distantPast

    // MARK: - Public

    public static func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        UIApplication.tf_swizzleSendEvent()
    }

    public static func disable() {
        isEnabled = false
    }

    // MARK: - Internal

    static func handleShake() {
        guard isEnabled else { return }
        // Debounce — simulator fires begin + end; only forward once per second.
        let now = Date()
        guard now.timeIntervalSince(lastShakeDate) > 1.0 else { return }
        lastShakeDate = now
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: shakeNotification, object: nil)
        }
    }
}

// MARK: - UIApplication swizzle

extension UIApplication {

    private static var _swizzled = false

    static func tf_swizzleSendEvent() {
        guard !_swizzled else { return }
        _swizzled = true

        let original = #selector(UIApplication.sendEvent(_:))
        let swizzled = #selector(UIApplication.tf_sendEvent(_:))

        guard
            let orig = class_getInstanceMethod(UIApplication.self, original),
            let swiz = class_getInstanceMethod(UIApplication.self, swizzled)
        else { return }

        method_exchangeImplementations(orig, swiz)
    }

    @objc func tf_sendEvent(_ event: UIEvent) {
        tf_sendEvent(event)   // calls original after swap — no infinite loop
        guard event.type == .motion, event.subtype == .motionShake else { return }
        ShakeDetector.handleShake()
    }
}
