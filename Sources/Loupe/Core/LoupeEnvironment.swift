import Foundation

/// Detects the current build environment so Loupe can self-disable in Release builds.
enum LoupeEnvironment {

    /// `true` when the app is compiled with the DEBUG flag.
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// `true` when running inside the Simulator.
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// `true` when running XCTest – avoids double-registering the URLProtocol.
    static var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    /// Returns a recommended `LoupeConfiguration` based on environment.
    static var recommendedConfiguration: LoupeConfiguration {
        isDebug ? .debug : .disabled
    }
}
