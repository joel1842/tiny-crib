public enum Suit: Int, CaseIterable, Comparable, Sendable {
    case spades, hearts, diamonds, clubs

    public var symbol: String {
        switch self {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
    }

    public var isRed: Bool { self == .hearts || self == .diamonds }

    public static func < (lhs: Suit, rhs: Suit) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Card: Hashable, Comparable, Sendable, CustomStringConvertible {
    public static let ranks = 1...13
    public static let jack = 11
    public static let fullDeck: [Card] = Suit.allCases.flatMap { suit in ranks.map { Card($0, suit) } }

    public let rank: Int
    public let suit: Suit

    public init(_ rank: Int, _ suit: Suit) {
        precondition(Self.ranks.contains(rank), "Card rank must be 1...13, got \(rank)")
        self.rank = rank
        self.suit = suit
    }

    public var value: Int { min(rank, 10) }

    public var label: String {
        switch rank {
        case 1: "A"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        default: String(rank)
        }
    }

    public var description: String { label + suit.symbol }

    public static func < (lhs: Card, rhs: Card) -> Bool {
        (lhs.rank, lhs.suit) < (rhs.rank, rhs.suit)
    }
}

public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
