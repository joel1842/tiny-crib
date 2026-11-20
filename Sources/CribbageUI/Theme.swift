import CribbageCore
import SwiftUI

enum Theme {
    static let me = Color(red: 0.38, green: 0.87, blue: 0.75)
    static let bot = Color(red: 1.0, green: 0.58, blue: 0.48)
    static let gold = Color(red: 1.0, green: 0.81, blue: 0.4)
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let suitRed = Color(red: 0.83, green: 0.13, blue: 0.23)
    static let suitBlack = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let paper = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let dim = Color.white.opacity(0.5)

    static func color(for player: Player) -> Color {
        player == .me ? me : bot
    }
}
