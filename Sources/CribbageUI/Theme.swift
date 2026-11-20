import CribbageCore
import SwiftUI

enum Theme {
    static let me = Color(red: 0.38, green: 0.87, blue: 0.75)
    static let them = Color(red: 1.0, green: 0.58, blue: 0.48)
    static let gold = Color(red: 1.0, green: 0.81, blue: 0.4)
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let cardRed = Color(red: 0.85, green: 0.17, blue: 0.24)
    static let neutral = Color(red: 0.14, green: 0.16, blue: 0.26)
    static let dim = Color.white.opacity(0.5)

    static func color(for player: Player) -> Color {
        player == .me ? me : them
    }
}
