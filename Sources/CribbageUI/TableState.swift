import CribbageCore
import SwiftUI

struct TableToast: Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

enum Pulse: Hashable {
    case score(Player)
    case count
}

enum CutStep {
    case deck, split, lift, reveal, done

    var showsFace: Bool { self == .reveal || self == .done }
    var lifted: Bool { self == .lift || self == .reveal }
    var isSplit: Bool { self == .split || self == .lift || self == .reveal }
}

enum DealCutStep {
    case centered, split, revealed, winner, gather, done

    var isOut: Bool { self == .split || self == .revealed || self == .winner }
    var faceUp: Bool { self == .revealed || self == .winner }
}

struct CountRow: Identifiable {
    let kind: ScoreKind
    let combos: [[Card]]
    let points: Int
    var id: ScoreKind { kind }
}

struct GoTag: Equatable {
    let player: Player
    let count: Int
}

struct Stage: Equatable {
    let gameNumber: Int
    let handNumber: Int
    let phase: Phase
}

extension Player {
    var name: String { self == .me ? "YOU" : "BOT" }
    var possessive: String { self == .me ? "YOUR" : "BOT'S" }
}
