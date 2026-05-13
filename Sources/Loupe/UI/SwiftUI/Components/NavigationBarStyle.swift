import SwiftUI

/// Flattens the navigation bar to a solid porcelain background and forces
/// toolbar buttons to read in ink color rather than the system blue tint.
/// Apply to the inner content of a `NavigationView` (alongside `.toolbar { }`).
struct TFNavigationBarStyle: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content
                .toolbarBackground(Color.tfBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .tint(Color.tfInk)
        } else {
            content
                .tint(Color.tfInk)
        }
    }
}

extension View {
    /// Applies the Loupe navigation bar treatment: solid porcelain
    /// background, ink-colored toolbar items.
    func tfNavigationBar() -> some View {
        modifier(TFNavigationBarStyle())
    }
}

/// Standard back/dismiss button used in the leading toolbar slot. Same shape
/// across pushed views and modal sheets — chevron + "Back" in ink.
struct TFBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                Text("Back").font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Color.tfInk)
        }
    }
}
