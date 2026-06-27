import SwiftUI
import UIKit

/// Le Castelet's palette — a warm little toy-theatre. Deep curtain reds, gilt brass, and a
/// stage-cream paper, each with a dark twin so the app feels at home day or night. One place
/// to tune the whole look.
enum Theme {
    static let velvet    = color(0x7A1F2B, 0x5A1620)   // curtain red — primary brand
    static let velvetDeep = color(0x5C141D, 0x3E0F16)  // shadowed velvet
    static let brass     = color(0xC9A24B, 0xD8B45E)   // gilt trim / accent
    static let stage     = color(0xF6ECD9, 0x1A1714)   // paper / app background
    static let board     = color(0xFFF8EC, 0x262019)   // cards, surfaces
    static let ink       = color(0x2A211A, 0xF1E7D6)   // primary text
    static let secondary = color(0x8A7A63, 0xB7A78C)   // secondary text
    static let faint     = color(0xCBB99A, 0x5A4E3C)   // dividers, dim marks
    static let footlight = color(0xE08A3C, 0xF0A155)   // warm spotlight glow

    // SwiftUI conveniences
    static var velvetC: Color { Color(uiColor: velvet) }
    static var velvetDeepC: Color { Color(uiColor: velvetDeep) }
    static var brassC: Color { Color(uiColor: brass) }
    static var stageC: Color { Color(uiColor: stage) }
    static var boardC: Color { Color(uiColor: board) }
    static var inkC: Color { Color(uiColor: ink) }
    static var secondaryC: Color { Color(uiColor: secondary) }
    static var faintC: Color { Color(uiColor: faint) }
    static var footlightC: Color { Color(uiColor: footlight) }

    private static func color(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) }
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

/// A serif display font for headings, giving the toy-theatre a hand-lettered playbill feel.
extension Font {
    static func playbill(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
