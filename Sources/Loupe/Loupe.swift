import UIKit
import SwiftUI
import Combine

/// Single entry point to the Loupe network logger.
///
/// **Minimal setup:**
/// ```swift
/// #if DEBUG
/// import Loupe
/// Loupe.shared.start()
/// #endif
/// ```
public final class Loupe: @unchecked Sendable {

    public static let shared = Loupe()
    private init() {}

    public private(set) var configuration = LoupeConfiguration()
    public private(set) var isRunning = false

    private var shakeObserver: NSObjectProtocol?
    private var isLoggerPresented = false
    private let remoteServer = RemoteServer()

    // MARK: - Start / Stop

    public func start(with config: LoupeConfiguration = LoupeConfiguration()) {
        guard config.isEnabled else { return }
        configuration = config
        Task { await LogManager.shared.configure(with: config) }
        NetworkInterceptor.register()
        #if canImport(UIKit)
        if config.autoScreenTracking     { ScreenTracker.enable() }
        #endif
        if config.shakeGestureEnabled    { enableShakeGesture() }
        if config.floatingButtonEnabled  { DispatchQueue.main.async { self.showFloatingButton() } }
        if config.remoteLoggingEnabled {
            Task { await remoteServer.start() }
        } else {
            print("[Loupe] Remote logging disabled (set remoteLoggingEnabled = true to enable).")
        }
        isRunning = true
        print("[Loupe] Started — capturing network traffic.")
    }

    public func stop() {
        NetworkInterceptor.unregister()
        disableShakeGesture()
        Task { @MainActor in self.hideFloatingButton() }
        Task { await remoteServer.stop() }
        isRunning = false
    }

    // MARK: - Log management

    public func clearLogs() { Task { await LogManager.shared.clearAll() } }

    // MARK: - Console (OSLog mirror)

    /// Append a single log line to the Loupe console.
    public func log(_ message: String,
                    level: LogMessage.Level = .info,
                    subsystem: String = "",
                    category: String = "") {
        Task { await LogMessageStore.shared.log(message, level: level,
                                                subsystem: subsystem, category: category) }
    }

    /// Start mirroring entries from the unified log store (iOS 15+ / macOS 12+).
    /// Pass the subsystems you want to surface in Loupe's console — typically
    /// your `Logger(subsystem:category:)` subsystem(s).
    public func startConsoleMirror(subsystems: Set<String>, interval: TimeInterval = 2.0) {
        Task { await LogMessageStore.shared.startMirroring(subsystems: subsystems, interval: interval) }
    }

    public func stopConsoleMirror() {
        Task { await LogMessageStore.shared.stopMirroring() }
    }

    // MARK: - Analytics events

    /// Record an analytics event (Mixpanel, Firebase, Adjust, Insider, Segment, …).
    /// Call this anywhere your app fires an analytics event — Loupe surfaces
    /// every recorded event in the Events tab, with per-provider filtering.
    ///
    /// ```swift
    /// Mixpanel.mainInstance().track(event: "LoginTapped", properties: props)
    /// Loupe.shared.trackEvent("LoginTapped", provider: "Mixpanel",
    ///                             properties: props.mapValues { "\($0)" })
    /// ```
    public func trackEvent(_ name: String,
                           provider: String = "Custom",
                           properties: [String: String] = [:],
                           screen: String? = nil) {
        Task { await AnalyticsEventStore.shared.track(name,
                                                      provider: provider,
                                                      properties: properties,
                                                      screen: screen) }
    }

    /// Convenience that accepts `[String: Any]` (the shape most SDKs use) and
    /// stringifies the values for storage.
    public func trackEvent(_ name: String,
                           provider: String = "Custom",
                           properties: [String: Any],
                           screen: String? = nil) {
        let stringified = properties.reduce(into: [String: String]()) { acc, kv in
            acc[kv.key] = "\(kv.value)"
        }
        trackEvent(name, provider: provider, properties: stringified, screen: screen)
    }

    /// Register the name of the currently visible screen. Subsequent
    /// `trackEvent(...)` calls without an explicit `screen` are tagged with
    /// this name, letting the macOS app group events by screen.
    ///
    /// Typically called from `viewDidAppear`, or via the SwiftUI modifier
    /// `.traceFlowScreen("HomeView")`.
    public func setCurrentScreen(_ name: String?) {
        Task { await AnalyticsEventStore.shared.setCurrentScreen(name) }
    }

    public func setMaxLogCount(_ count: Int) {
        configuration.maxLogCount = count
        Task { await LogManager.shared.configure(with: configuration) }
    }

    // MARK: - Security

    public func addCustomHeaderMasking(_ headerName: String) {
        configuration.sensitiveHeaders.insert(headerName)
        Task { await LogManager.shared.configure(with: configuration) }
    }

    public func addSensitiveKey(_ key: String) {
        configuration.sensitiveBodyKeys.insert(key)
        Task { await LogManager.shared.configure(with: configuration) }
    }

    // MARK: - Custom session injection (optional override)

    /// Manually inject the interceptor into a specific `URLSessionConfiguration`.
    /// Not required for most setups — Loupe automatically hooks all
    /// URLSession initialisers (including Alamofire) at startup.
    public func configure(session config: URLSessionConfiguration) {
        NetworkInterceptor.inject(into: config)
    }

    // MARK: - Mock engine

    public var mockEngine: MockEngine { MockEngine.shared }

    // MARK: - UI

    @MainActor
    public func showLogger(from viewController: UIViewController? = nil) {
        guard !isLoggerPresented else { return }
        isLoggerPresented = true
        LoupeViewController.present(from: viewController)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.isLoggerPresented = false }
    }

    // MARK: - Shake gesture

    public func enableShakeGesture() {
        configuration.shakeGestureEnabled = true
        ShakeDetector.enable()
        guard shakeObserver == nil else { return }
        shakeObserver = NotificationCenter.default.addObserver(
            forName: ShakeDetector.shakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.showLogger() }
        }
    }

    public func disableShakeGesture() {
        configuration.shakeGestureEnabled = false
        ShakeDetector.disable()
        if let obs = shakeObserver { NotificationCenter.default.removeObserver(obs); shakeObserver = nil }
    }

    // MARK: - Floating button

    private var floatingWindow: UIWindow?

    @MainActor
    public func showFloatingButton() {
        guard floatingWindow == nil,
              let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive })
        else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.rootViewController = UIHostingController(rootView: FloatingDebugButton())
        window.rootViewController?.view.backgroundColor = .clear
        window.makeKeyAndVisible()
        floatingWindow = window
    }

    @MainActor
    public func hideFloatingButton() {
        floatingWindow?.isHidden = true
        floatingWindow = nil
    }

    // MARK: - Combine / async

    public var entriesPublisher: AnyPublisher<[NetworkEntry], Never> {
        LogManager.shared.entriesPublisher
    }

    public func allEntries() async -> [NetworkEntry] {
        await LogManager.shared.allEntries()
    }
}

// MARK: - SwiftUI modifier

public struct LoupeModifier: ViewModifier {
    @Binding var isPresented: Bool
    public func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            LoupeView(isPresented: $isPresented)
        }
    }
}

public extension View {
    func traceFlowLogger(isPresented: Binding<Bool>) -> some View {
        modifier(LoupeModifier(isPresented: isPresented))
    }

    /// Tag the view with a screen name so analytics events fired while it is
    /// visible are categorised under this screen in the Loupe UI.
    ///
    /// ```swift
    /// HomeView()
    ///     .traceFlowScreen("HomeView")
    /// ```
    func traceFlowScreen(_ name: String) -> some View {
        onAppear     { Loupe.shared.setCurrentScreen(name) }
        .onDisappear { Loupe.shared.setCurrentScreen(nil)  }
    }
}
