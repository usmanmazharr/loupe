import SwiftUI

/// Design tokens for spacing, radii, and typography. Color tokens live on
/// `Color` (see `Color+Extensions.swift`).
public enum TF {

    // MARK: - Spacing

    public enum Space {
        public static let xxs: CGFloat = 4
        public static let xs:  CGFloat = 8
        public static let sm:  CGFloat = 12
        public static let md:  CGFloat = 16
        public static let lg:  CGFloat = 24
        public static let xl:  CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Radii

    public enum Radius {
        public static let chip:  CGFloat = 6
        public static let card:  CGFloat = 10
        public static let sheet: CGFloat = 14
    }

    // MARK: - Typography
    //
    // Sizes are explicit (no .footnote / .caption Dynamic Type magic) so the
    // visual hierarchy stays consistent across iOS and macOS.

    public enum Font {
        public static let title    = SwiftUI.Font.system(size: 17, weight: .semibold)
        public static let headline = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let body     = SwiftUI.Font.system(size: 13)
        public static let caption  = SwiftUI.Font.system(size: 11)
        public static let tag      = SwiftUI.Font.system(size: 10, weight: .semibold, design: .monospaced)
        public static let mono     = SwiftUI.Font.system(size: 12, design: .monospaced)
    }
}
