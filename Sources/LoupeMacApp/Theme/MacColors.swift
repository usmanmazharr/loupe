import SwiftUI
import AppKit

// Mirror of the iOS design tokens so the companion app reads with the same
// porcelain · ink · sapphire palette. Colors are dynamic and switch with the
// system appearance.

extension Color {

    // MARK: - Surface

    static let lpBackground = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0xFAFAFC),
        dark:  NSColor(hex: 0x0E0F13)
    ))

    static let lpCard = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0xFFFFFF),
        dark:  NSColor(hex: 0x16181D)
    ))

    static let lpSurface = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0xF2F3F7),
        dark:  NSColor(hex: 0x1B1E24)
    ))

    static let lpHairline = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0xE6E8EE),
        dark:  NSColor(hex: 0x22252B)
    ))

    // MARK: - Foreground

    static let lpInk = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0x0F1115),
        dark:  NSColor(hex: 0xF4F5F7)
    ))

    static let lpFog = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0x6E7280),
        dark:  NSColor(hex: 0x9099A8)
    ))

    // MARK: - Accent

    static let lpAccent = Color(nsColor: NSColor(hex: 0x1B4DFF))

    static let lpAccentSoft = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0x1B4DFF).withAlphaComponent(0.10),
        dark:  NSColor(hex: 0x5E7BFF).withAlphaComponent(0.18)
    ))

    // MARK: - Semantic

    static let lpSuccess = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0x1F9D55),
        dark:  NSColor(hex: 0x4FBE7A)
    ))
    static let lpWarning = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0xB58100),
        dark:  NSColor(hex: 0xE0AC4A)
    ))
    static let lpDanger = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0xC24545),
        dark:  NSColor(hex: 0xE07070)
    ))
    static let lpCritical = Color(nsColor: NSColor.macDynamic(
        light: NSColor(hex: 0x8B1E1E),
        dark:  NSColor(hex: 0xC95757)
    ))

    // MARK: - Helpers

    static func lpMethodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET":     return .lpAccent
        case "POST":    return .lpSuccess
        case "PUT":     return .lpWarning
        case "PATCH":   return Color(nsColor: NSColor(hex: 0xC97A00))
        case "DELETE":  return .lpDanger
        case "HEAD":    return Color(nsColor: NSColor(hex: 0x5B4DBE))
        case "OPTIONS": return Color(nsColor: NSColor(hex: 0x7A5BBE))
        default:        return .lpFog
        }
    }

    static func lpStatusColor(_ code: Int?) -> Color {
        guard let code else { return .lpFog }
        switch code {
        case 200..<300: return .lpSuccess
        case 300..<400: return .lpWarning
        case 400..<500: return .lpDanger
        case 500..<600: return .lpCritical
        default:        return .lpFog
        }
    }
}

extension NSColor {
    static func macDynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return isDark ? dark : light
        }
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >>  8) & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Spacing / Radius / Type

enum MF {
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
    }
    enum Radius {
        static let chip: CGFloat = 6
        static let card: CGFloat = 10
        static let sheet: CGFloat = 14
    }
}
