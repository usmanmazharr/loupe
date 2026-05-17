import Foundation
import UIKit

/// Central configuration for Loupe network logger.
public struct LoupeConfiguration {

    // MARK: - Storage

    /// Maximum number of log entries retained in memory.
    public var maxLogCount: Int = 500

    /// Enable persistent disk storage (file-based JSON).
    public var enablePersistentStorage: Bool = false

    // MARK: - Capture

    /// Whether Loupe captures network traffic.
    public var isEnabled: Bool = true

    /// Only log requests matching these hosts. Empty = log all.
    public var allowedHosts: Set<String> = []

    /// Never log requests matching these hosts.
    public var ignoredHosts: Set<String> = []

    /// Ignore requests whose URL contains any of these path components.
    public var ignoredPathComponents: [String] = []

    /// Maximum body size (bytes) stored per request/response. 0 = unlimited.
    public var maxBodySize: Int = 1_024 * 1_024 // 1 MB

    // MARK: - Security

    /// Header names whose values should be masked.
    public var sensitiveHeaders: Set<String> = [
        "Authorization",
        "Cookie",
        "Set-Cookie",
        "X-Api-Key",
        "X-Auth-Token",
        "X-Access-Token",
        "Proxy-Authorization"
    ]

    /// JSON body keys whose values should be masked.
    public var sensitiveBodyKeys: Set<String> = [
        "password",
        "token",
        "secret",
        "api_key",
        "apiKey",
        "access_token",
        "accessToken",
        "refresh_token",
        "refreshToken",
        "credit_card",
        "creditCard",
        "cvv",
        "ssn"
    ]

    /// Replacement string shown for masked values.
    public var maskingString: String = "••••••••"

    // MARK: - Environment

    /// A label shown in the Loupe UI so you can tell at a glance which
    /// backend the app is talking to (e.g. "UAT", "Production", "Staging").
    public var environmentName: String?

    // MARK: - Appearance

    /// Force a specific color scheme for the Loupe UI.
    /// `.unspecified` (default) follows the device system setting.
    /// Set to `.dark` or `.light` to override.
    public var userInterfaceStyle: UIUserInterfaceStyle = .dark

    // MARK: - Shake Gesture

    /// Present the logger UI when the device is shaken.
    public var shakeGestureEnabled: Bool = true

    // MARK: - Floating Button

    /// Show a persistent floating debug button.
    public var floatingButtonEnabled: Bool = false

    // MARK: - OSLog

    /// Mirror captured requests to OSLog/unified logging.
    public var osLogEnabled: Bool = false

    // MARK: - Screen Tracking

    /// Automatically detect the current screen name from UIViewController lifecycle.
    ///
    /// When enabled (the default) Loupe swizzles `UIViewController.viewDidAppear`
    /// to update the current screen name whenever a new view controller appears.
    /// The name is derived from the class name with common suffixes removed:
    /// `HomeViewController` → `"Home"`, `OffersController` → `"Offers"`.
    ///
    /// System / framework classes (names starting with `UI`, `_`, `SwiftUI`, etc.)
    /// and `UIHostingController` are silently ignored.
    ///
    /// For SwiftUI views use `.traceFlowScreen("Name")` instead — it always wins
    /// over the auto-detected name.
    public var autoScreenTracking: Bool = true

    // MARK: - Remote Logging

    /// Stream captured entries to the LoupeMacApp companion over local Wi-Fi.
    /// Both devices must be on the same network; the macOS app discovers the device via Bonjour.
    ///
    /// Also add to your app's Info.plist:
    ///   NSLocalNetworkUsageDescription  (any explanation string)
    ///   NSBonjourServices               → _loupe._tcp.
    public var remoteLoggingEnabled: Bool = false

    /// Serve a web dashboard on a localhost HTTP port so anyone on the same
    /// Wi-Fi can view captured traffic in a browser (no Mac app needed).
    /// Open `http://<device-ip>:<webDashboardPort>` in any browser.
    public var webDashboardEnabled: Bool = false

    /// TCP port for the web dashboard HTTP server (default 9800).
    public var webDashboardPort: UInt16 = 9800

    // MARK: - Factory

    public init() {}

    /// Returns a configuration with all features enabled – useful for debug targets.
    public static var debug: LoupeConfiguration {
        var config = LoupeConfiguration()
        config.isEnabled              = true
        config.shakeGestureEnabled    = true
        config.osLogEnabled           = true
        config.enablePersistentStorage = true
        config.remoteLoggingEnabled   = true
        config.webDashboardEnabled    = true
        return config
    }

    /// Returns a no-op configuration – use this in Release builds.
    public static var disabled: LoupeConfiguration {
        var config = LoupeConfiguration()
        config.isEnabled = false
        config.shakeGestureEnabled = false
        config.floatingButtonEnabled = false
        config.osLogEnabled = false
        return config
    }
}
