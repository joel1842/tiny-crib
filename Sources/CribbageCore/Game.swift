public enum Player: Hashable, Sendable {
    case me, bot

    public var other: Player { self == .me ? .bot : .me }
}

public enum ShowStep: Int, Sendable {
    case pone, dealer, crib
}

public enum Phase: Equatable, Sendable {
    case discard
    case play
    case show(ShowStep)
    case gameOver(winner: Player)
}

public enum ScoreReason: Equatable, Sendable {
    case pegging(ScoreKind, String)
    case saidGo
    case go
    case lastCard
    case heels
    case hand
    case crib

    public var label: String {
        switch self {
        case .pegging(_, let label): label
        case .saidGo, .go: "go"
        case .lastCard: "last card"
        case .heels: "his heels"
        case .hand: "hand"
        case .crib: "crib"
        }
    }

    public var isShow: Bool { self == .hand || self == .crib }
}

public struct ScoreEvent: Equatable, Sendable {
    public let player: Player
    public let points: Int
    public let reason: ScoreReason
}

public struct PlayedCard: Equatable, Sendable {
    public let card: Card
    public let player: Player
    public let round: Int
    public internal(set) var points = 0
}

public struct DealCut: Equatable, Sendable {
    public let me: Card
    public let bot: Card

    public func card(for player: Player) -> Card { player == .me ? me : bot }
}

public struct Showing: Equatable, Sendable {
    public let player: Player
    public let isCrib: Bool
    public let cards: [Card]
    public let score: HandScore
}

public struct Game: Sendable {
    public static let target = 121
    public static let skunkLine = 91
    public static let doubleSkunkLine = 61
    public static let maxCount = 31
    public static let dealtHandSize = 6

    public private(set) var scores: [Player: Int] = [.me: 0, .bot: 0]
    public private(set) var dealer: Player
    public private(set) var phase: Phase = .discard
    public private(set) var hands: [Player: [Card]] = [:]
    public private(set) var inHand: [Player: [Card]] = [:]
    public private(set) var crib: [Card] = []
    public private(set) var starter: Card?
    public private(set) var played: [PlayedCard] = []
    public private(set) var round = 0
    public private(set) var count = 0
    public private(set) var turn: Player
    public private(set) var events: [ScoreEvent] = []
    public private(set) var dealCut: DealCut
    public private(set) var handNumber = 0
    public private(set) var winningShowing: Showing?
    public private(set) var backPegs: [Player: Int] = [:]
    private var moveStart: [Player: Int] = [:]
    private var wentGo: Set<Player> = []
    private var deck: [Card] = []
    private var rng: SeededGenerator

    public init(seed: UInt64 = .random(in: .min ... .max)) {
        rng = SeededGenerator(seed: seed)
        var cut: [Card]
        repeat {
            cut = Array(Card.fullDeck.shuffled(using: &rng).prefix(2))
        } while cut[0].rank == cut[1].rank
        dealCut = DealCut(me: cut[0], bot: cut[1])
        dealer = cut[0].rank < cut[1].rank ? .me : .bot
        turn = dealer.other
        startHand()
    }

    public var isOver: Bool {
        if case .gameOver = phase { return true }
        return false
    }

    public var sequence: [Card] { played.filter { $0.round == round }.map(\.card) }

    public var showing: Showing? {
        guard case .show(let step) = phase, let starter else { return nil }
        let player = step == .pone ? dealer.other : dealer
        let isCrib = step == .crib
        let cards = isCrib ? crib : hands[player, default: []]
        return Showing(player: player, isCrib: isCrib, cards: cards, score: HandScorer.score(hand: cards, starter: starter, isCrib: isCrib))
    }

    public func canPlay(_ player: Player) -> Bool {
        inHand[player, default: []].contains { count + $0.value <= Self.maxCount }
    }

    public mutating func discard(_ cards: [Card], by player: Player) {
        let hand = hands[player, default: []]
        guard phase == .discard, cards.count == 2, hand.count == Self.dealtHandSize, cards.allSatisfy(hand.contains) else { return }
        hands[player]?.removeAll { cards.contains($0) }
        crib += cards
        if crib.count == HandScorer.handSize { cutStarter() }
    }

    @discardableResult
    public mutating func play(_ card: Card, by player: Player) -> Bool {
        guard phase == .play, turn == player, inHand[player, default: []].contains(card),
              count + card.value <= Self.maxCount else { return false }
        moveStart = scores
        inHand[player]?.removeAll { $0 == card }
        played.append(PlayedCard(card: card, player: player, round: round))
        count += card.value
        for item in PeggingScorer.score(sequence: sequence, count: count) where !isOver {
            awardForLastCard(player, item.points, .pegging(item.kind, item.label))
        }
        if !isOver { advanceTurn(after: player) }
        return true
    }

    public mutating func advanceShow() {
        guard case .show(let step) = phase else { return }
        switch step {
        case .pone: enterShow(.dealer)
        case .dealer: enterShow(.crib)
        case .crib:
            dealer = dealer.other
            startHand()
        }
    }

    private mutating func startHand() {
        handNumber += 1
        deck = Card.fullDeck.shuffled(using: &rng)
        let dealt = Self.dealtHandSize
        hands = [
            .me: deck[0..<dealt].sorted(),
            .bot: deck[dealt..<dealt * 2].sorted(),
        ]
        deck.removeFirst(dealt * 2)
        inHand = [:]
        crib = []
        starter = nil
        played = []
        round = 0
        count = 0
        wentGo = []
        turn = dealer.other
        phase = .discard
    }

    private mutating func cutStarter() {
        let card = deck.removeFirst()
        starter = card
        moveStart = scores
        if card.rank == Card.jack { award(dealer, 2, .heels) }
        guard !isOver else { return }
        inHand = hands
        turn = dealer.other
        phase = .play
    }

    private mutating func advanceTurn(after last: Player) {
        if count == Self.maxCount { newRound() }

        if inHand.values.allSatisfy(\.isEmpty) {
            if count > 0 { awardForLastCard(last, 1, .lastCard) }
            if !isOver { enterShow(.pone) }
            return
        }

        let next = last.other
        if canPlay(next) {
            turn = next
            return
        }
        if !inHand[next, default: []].isEmpty && !wentGo.contains(next) {
            wentGo.insert(next)
            events.append(ScoreEvent(player: next, points: 0, reason: .saidGo))
        }
        if canPlay(last) {
            turn = last
            return
        }

        awardForLastCard(last, 1, .go)
        guard !isOver else { return }
        newRound()
        turn = inHand[next, default: []].isEmpty ? last : next
    }

    private mutating func newRound() {
        round += 1
        count = 0
        wentGo = []
    }

    private mutating func enterShow(_ step: ShowStep) {
        phase = .show(step)
        moveStart = scores
        guard let showing else { return }
        award(showing.player, showing.score.total, showing.isCrib ? .crib : .hand)
        if isOver { winningShowing = showing }
    }

    private mutating func awardForLastCard(_ player: Player, _ points: Int, _ reason: ScoreReason) {
        award(player, points, reason)
        played[played.count - 1].points += points
    }

    private mutating func award(_ player: Player, _ points: Int, _ reason: ScoreReason) {
        guard points > 0, !isOver else { return }
        backPegs[player] = moveStart[player] ?? scores[player, default: 0]
        let total = min(scores[player, default: 0] + points, Self.target)
        scores[player] = total
        events.append(ScoreEvent(player: player, points: points, reason: reason))
        if total >= Self.target { phase = .gameOver(winner: player) }
    }
}

extension Game {
    static func atPlay(dealer: Player, hands: [Player: [Card]], starter: Card, scores: [Player: Int] = [.me: 0, .bot: 0]) -> Game {
        var game = Game(seed: 1)
        game.dealer = dealer
        game.hands = hands
        game.inHand = hands
        game.starter = starter
        game.scores = scores
        game.turn = dealer.other
        game.phase = .play
        return game
    }
}
