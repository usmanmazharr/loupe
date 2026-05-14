#if canImport(UIKit)
import UIKit
import ObjectiveC

/// Automatically tracks the currently visible screen name by swizzling
/// `UIViewController.viewDidAppear(_:)`.
///
/// Activated when `LoupeConfiguration.autoScreenTracking` is `true` (the default).
///
/// - UIKit view controllers have their class name cleaned and used as the screen
///   name: `HomeViewController` → `"Home"`, `OffersController` → `"Offers"`.
/// - System/framework view controllers (names starting with `UI`, `_`, `SwiftUI`,
///   etc.) are silently skipped.
/// - `UIHostingController` is also skipped — use the `.traceFlowScreen("Name")`
///   SwiftUI modifier for SwiftUI screens instead.
/// - Manual calls to `Loupe.shared.setCurrentScreen(_:)` or the
///   `.traceFlowScreen()` modifier always win over auto-detection.
public enum ScreenTracker {

    // MARK: - Activation

    /// Swizzles `UIViewController.viewDidAppear(_:)` once.
    /// Calling this more than once is safe — the `_once` guard ensures
    /// the exchange only happens a single time per process lifetime.
    public static func enable() {
        _ = _once
    }

    // MARK: - Private

    private static let _once: Void = {
        let sel         = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSel = #selector(UIViewController.lp_viewDidAppear(_:))
        guard
            let original = class_getInstanceMethod(UIViewController.self, sel),
            let swizzled = class_getInstanceMethod(UIViewController.self, swizzledSel)
        else { return }
        method_exchangeImplementations(original, swizzled)
    }()

    // MARK: - Name extraction

    /// Returns a clean, human-readable screen name for `vc`, or `nil` if the
    /// view controller should be ignored (system / hosting / container types).
    static func screenName(for vc: UIViewController) -> String? {
        let className = String(describing: type(of: vc))

        // ── Skip system / framework classes ──────────────────────────────
        let skipPrefixes = [
            "UI", "_", "SwiftUI", "NSUI", "PL", "SB",
            "AB", "MK", "AV", "SF", "CNContact", "PKPayment",
            "PHPicker", "GLK", "SCN", "RealityKit"
        ]
        for prefix in skipPrefixes where className.hasPrefix(prefix) { return nil }

        // UIHostingController<T> — defer to .traceFlowScreen() modifier
        if className.hasPrefix("UIHostingController") { return nil }

        // ── Strip module prefix (e.g. "MyApp.HomeViewController" → "HomeViewController")
        let bare = className.components(separatedBy: ".").last ?? className

        // ── Strip common suffixes ─────────────────────────────────────────
        var name = bare
        for suffix in ["ViewController", "Controller", "VC"] {
            if name.hasSuffix(suffix), name.count > suffix.count {
                name = String(name.dropLast(suffix.count))
                break
            }
        }

        return name.isEmpty ? nil : name
    }
}

// MARK: - UIViewController swizzled method

extension UIViewController {
    /// Swapped with `viewDidAppear(_:)` by `ScreenTracker.enable()`.
    @objc func lp_viewDidAppear(_ animated: Bool) {
        // After the method exchange this line calls the *original* viewDidAppear.
        lp_viewDidAppear(animated)

        guard let name = ScreenTracker.screenName(for: self) else { return }
        Loupe.shared.setCurrentScreen(name)
    }
}
#endif
