import UIKit
import SwiftUI

extension UIUserInterfaceStyle {
    /// Maps to the SwiftUI `ColorScheme` used by `.preferredColorScheme()`.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark:  return .dark
        case .light: return .light
        default:     return nil   // nil = follow system
        }
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController?.topMost
    }
}

extension UIViewController {
    var topMost: UIViewController {
        if let presented = presentedViewController { return presented.topMost }
        if let nav = self as? UINavigationController { return nav.visibleViewController?.topMost ?? self }
        if let tab = self as? UITabBarController { return tab.selectedViewController?.topMost ?? self }
        return self
    }
}
