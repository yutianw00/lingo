import SwiftUI
import UIKit

/// Colors from web/src/styles.css, with the same light / dark variants.
enum Theme {
    private static func dynamic(_ light: UInt32, _ dark: UInt32? = nil) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark ?? light) : UIColor(hex: light) })
    }

    static let bg = dynamic(0xF6F7FB, 0x12141C)
    static let card = dynamic(0xFFFFFF, 0x1C1F2A)
    static let ink = dynamic(0x1F2433, 0xECEEF5)
    static let muted = dynamic(0x7A8194, 0x9298AA)
    static let line = dynamic(0xE6E8F0, 0x2C3040)
    static let lineDark = dynamic(0xD5D8E2, 0x3A3F52)
    static let primary = dynamic(0x4F6BFF)
    static let primaryDark = dynamic(0x3A52D6)
    static let soft = dynamic(0xEEF1FF, 0x262D52)
    static let good = dynamic(0x22B07D)
    static let goodDark = dynamic(0x178A61)
    static let goodSoft = dynamic(0xE3F7EF, 0x163A2E)
    static let bad = dynamic(0xEF5160)
    static let badDark = dynamic(0xC93A48)
    static let badSoft = dynamic(0xFDE8EA, 0x43202A)
    static let warn = dynamic(0xFFB020)
    static let warnDark = dynamic(0xB57700)
    static let warnSoft = dynamic(0xFFF4DC, 0x3D3016)

    static func level(_ l: Level) -> Color {
        switch l {
        case .new: dynamic(0xC9CDD8, 0x4A4F62)
        case .learning: dynamic(0xFF8A5B)
        case .familiar: dynamic(0xFFB020)
        case .mastered: dynamic(0x22B07D)
        }
    }

    static func lang(_ l: Lang) -> Color {
        switch l {
        case .zh: dynamic(0xE5484D)
        case .en: dynamic(0x3E63DD)
        case .fr: dynamic(0x6E56CF)
        case .es: dynamic(0xF76B15)
        }
    }

    /// Gender badge text color (background is the same color, faded).
    static func gender(_ g: Gender) -> Color {
        switch g {
        case .m: dynamic(0x2F54C8, 0xA8C0FF)
        case .f: dynamic(0xB8336A, 0xF5A8C8)
        default: dynamic(0x6B4BB8, 0xCDB8FF)
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
