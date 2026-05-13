import SwiftUI
import Combine

/// Shared theme state. SwiftUI views observe via @ObservedObject;
/// UIKit hosts subscribe via Combine to set overrideUserInterfaceStyle.
final class LoupeThemeManager: ObservableObject {

    static let shared = LoupeThemeManager()

    @Published private(set) var colorScheme: ColorScheme
    @Published private(set) var uiStyle: UIUserInterfaceStyle

    private init() {
        let isLight = Loupe.shared.configuration.userInterfaceStyle == .light
        self.colorScheme = isLight ? .light : .dark
        self.uiStyle     = isLight ? .light : .dark
    }

    func toggle() {
        let next: ColorScheme = colorScheme == .dark ? .light : .dark
        colorScheme = next
        uiStyle     = next == .dark ? .dark : .light
    }
}
