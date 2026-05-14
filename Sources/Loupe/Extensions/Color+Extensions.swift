import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design tokens
//
// Porcelain · Ink · Sapphire — a cool, minimal palette tuned for long debugging
// sessions. Colors are dynamic (UIColor providers) so they switch automatically
// between light and dark. Semantic shades are intentionally muted so the UI
// reads calm and editorial rather than dashboard-y.

extension Color {

    // MARK: - Surface

    /// Page background. Cool porcelain in light, deep obsidian in dark.
    static let lpBackground = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xFAFAFC),
        dark:  UIColor(hex: 0x0E0F13)
    ))

    /// Primary card surface — used for rows and content containers.
    static let lpCardBackground = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xFFFFFF),
        dark:  UIColor(hex: 0x16181D)
    ))

    /// Nested surface — used inside a card (e.g. code blocks, property rows).
    static let lpSurface = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xF2F3F7),
        dark:  UIColor(hex: 0x1B1E24)
    ))

    /// Hairline dividers. One pixel of contrast — never heavier.
    static let lpHairline = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xE6E8EE),
        dark:  UIColor(hex: 0x22252B)
    ))

    /// Legacy alias.
    static let lpSeparator = lpHairline

    // MARK: - Foreground

    /// Primary text. Near-black ink in light, porcelain reversed in dark.
    static let lpInk = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x0F1115),
        dark:  UIColor(hex: 0xF4F5F7)
    ))

    /// Secondary text — slate fog.
    static let lpFog = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x6E7280),
        dark:  UIColor(hex: 0x9099A8)
    ))

    /// Tertiary / very subtle text.
    static let lpMist = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x9CA3AF),
        dark:  UIColor(hex: 0x666D78)
    ))

    // MARK: - Accent

    /// Sapphire — the single brand accent. Same in both modes.
    static let lpAccent = Color(uiColor: UIColor(hex: 0x1B4DFF))

    /// Muted sapphire tint for backgrounds.
    static let lpAccentSoft = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x1B4DFF).withAlphaComponent(0.10),
        dark:  UIColor(hex: 0x5E7BFF).withAlphaComponent(0.18)
    ))

    // MARK: - Semantic status (muted)

    static let lpSuccess  = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x1F9D55),
        dark:  UIColor(hex: 0x4FBE7A)
    ))
    static let lpWarning  = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xB58100),
        dark:  UIColor(hex: 0xE0AC4A)
    ))
    static let lpDanger   = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xC24545),
        dark:  UIColor(hex: 0xE07070)
    ))
    static let lpCritical = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x8B1E1E),
        dark:  UIColor(hex: 0xC95757)
    ))

    // MARK: - HTTP status

    static func statusColor(for code: Int?) -> Color {
        guard let code else { return .lpFog }
        switch code {
        case 200..<300: return .lpSuccess
        case 300..<400: return .lpWarning
        case 400..<500: return .lpDanger
        case 500..<600: return .lpCritical
        default:        return .lpFog
        }
    }

    // MARK: - HTTP method (muted, harmonized with palette)

    static func methodColor(for method: String) -> Color {
        switch method.uppercased() {
        case "GET":     return .lpAccent                                  // sapphire
        case "POST":    return .lpSuccess                                 // muted green
        case "PUT":     return .lpWarning                                 // muted amber
        case "PATCH":   return Color(uiColor: UIColor(hex: 0xC97A00))     // burnt amber
        case "DELETE":  return .lpDanger                                  // muted red
        case "HEAD":    return Color(uiColor: UIColor(hex: 0x5B4DBE))     // soft indigo
        case "OPTIONS": return Color(uiColor: UIColor(hex: 0x7A5BBE))     // soft purple
        default:        return .lpFog
        }
    }

    // MARK: - JSON syntax (muted, premium)

    static let jsonKey    = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x6E40A0),
        dark:  UIColor(hex: 0xB18EE0)
    ))
    static let jsonString = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x1F7A2D),
        dark:  UIColor(hex: 0x6FCB7E)
    ))
    static let jsonNumber = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0x1B4DFF),
        dark:  UIColor(hex: 0x6F8FFF)
    ))
    static let jsonBool   = Color(uiColor: UIColor.lpDynamic(
        light: UIColor(hex: 0xB55A00),
        dark:  UIColor(hex: 0xE0995C)
    ))
    static let jsonNull   = Color.lpFog
}

// MARK: - UIColor helpers

#if canImport(UIKit)
extension UIColor {

    /// Builds a dynamic color that switches between `light` and `dark` based on
    /// the resolving trait collection. Falls back to `light` on older OS.
    static func lpDynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    /// Builds a UIColor from a 0xRRGGBB hex literal.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >>  8) & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
#endif
