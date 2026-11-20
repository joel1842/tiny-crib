public enum Player: Hashable, Sendable {
    case me, them

    public var other: Player { self == .me ? .them : .me }
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

public struct ScoreEvent: Equatable, Sendable {
    public let player: Player
    public let points: Int
    public let label: String
}

public struct PlayedCard: Equatable, Sendable {
    public let card: Card
    public let player: Player
    public let round: Int
    public internal(set) var points = 0
}

public struct DealCut: Equatable, Sendable {
    public let me: Card
    public let them: Card
}

public struct Showing: Equatable, Sendable {
    public let player: Player
    public let isCrib: Bool
    public let cards: [Card]
    public let score: HandScore
}

public struct Game: Sendable {
    public static let target = 121

    public private(set) var scores: [Player: Int] = [.me: 0, .them: 0]
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
    public private(set) var lastShowing: Showing?
    public private(set) var backPegs: [Player: Int] = [:]
    private var moveStart: [Player: Int] = [:]
    private var wentGo: Set<Player> = []
    private var deck: [Card] = []
    private var rng: SeededGenerator

    public init(seed: UInt64 = UInt64.random(in: .min ... .max)) {
        rng = SeededGenerator(seed: seed)
        var cut: [Card]
        repeat {
            cut = Array(Card.fullDeck.shuffled(using: &rng).prefix(2))
        } while cut[0].rank == cut[1].rank
        dealCut = DealCut(me: cut[0], them: cut[1])
        dealer = cut[0].rank < cut[1].rank ? .me : .them
        turn = dealer.other
        startHand()
    }

    public var isOver: Bool {
        if case .gameOver = phase { return true }
        return false
    }

    public var sequence: [Card] { played.filter { $0.round == round }.map(\.card) }

    public var showing: Showing? {
        guard case .show(let step) = phase else { return nil }
        guard let starter else { return nil }
        let player = step == .pone ? dealer.other : dealer
        let isCrib = step == .crib
        let cards = isCrib ? crib : hands[player, default: []]
        return Showing(player: player, isCrib: isCrib, cards: cards, score: HandScorer.score(hand: cards, starter: starter, isCrib: isCrib))
    }

    public func canPlay(_ player: Player) -> Bool {
        inHand[player, default: []].contains { count + $0.value <= 31 }
    }

    public mutating func discard(_ cards: [Card], by player: Player) {
        guard phase == .discard, cards.count == 2, hands[player, default: []].count == 6,
              cards.allSatisfy({ hands[player, default: []].contains($0) }) else { return }
        hands[player]?.removeAll { cards.contains($0) }
        crib += cards
        if crib.count == 4 { cutStarter() }
    }

    @discardableResult
    public mutating func play(_ card: Card, by player: Player) -> Bool {
        guard phase == .play, turn == player, inHand[player, default: []].contains(card),
              count + card.value <= 31 else { return false }
        moveStart = scores
        inHand[player]?.removeAll { $0 == card }
        played.append(PlayedCard(card: card, player: player, round: round))
        count += card.value
        for item in PeggingScorer.score(sequence: sequence, count: count) {
            guard !isOver else { break }
            award(player, item.points, item.label)
            played[played.count - 1].points += item.points
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

    mutating func startHand() {
        handNumber += 1
        deck = Card.fullDeck.shuffled(using: &rng)
        hands = [
            .me: deck[0..<6].sorted(by: Self.displayOrder),
            .them: deck[6..<12].sorted(by: Self.displayOrder),
        ]
        deck.removeFirst(12)
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

    mutating func cutStarter() {
        let card = deck.removeFirst()
        starter = card
        moveStart = scores
        if card.rank == 11 { award(dealer, 2, "his heels") }
        guard !isOver else { return }
        inHand = hands
        turn = dealer.other
        phase = .play
    }

    mutating func advanceTurn(after last: Player) {
        if count == 31 { newRound() }

        if inHand.values.allSatisfy(\.isEmpty) {
            if count > 0 {
                award(last, 1, "last card")
                played[played.count - 1].points += 1
            }
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
            events.append(ScoreEvent(player: next, points: 0, label: "go"))
        }
        if canPlay(last) {
            turn = last
            return
        }

        award(last, 1, "go")
        played[played.count - 1].points += 1
        guard !isOver else { return }
        newRound()
        turn = inHand[next, default: []].isEmpty ? last : next
    }

    mutating func newRound() {
        round += 1
        count = 0
        wentGo = []
    }

    mutating func enterShow(_ step: ShowStep) {
        phase = .show(step)
        moveStart = scores
        if let showing {
            lastShowing = showing
            let label = showing.isCrib ? "crib" : "hand"
            award(showing.player, showing.score.total, label)
        }
    }

    mutating func award(_ player: Player, _ points: Int, _ label: String) {
        guard points > 0, !isOver else { return }
        backPegs[player] = moveStart[player] ?? scores[player, default: 0]
        let total = min(scores[player, default: 0] + points, Self.target)
        scores[player] = total
        events.append(ScoreEvent(player: player, points: points, label: label))
        if total >= Self.target { phase = .gameOver(winner: player) }
    }

    static func displayOrder(_ a: Card, _ b: Card) -> Bool {
        a.rank == b.rank ? a.suit.rawValue < b.suit.rawValue : a.rank < b.rank
    }
}

extension Game {
    static func atPlay(dealer: Player, hands: [Player: [Card]], starter: Card) -> Game {
        var game = Game(seed: 1)
        game.dealer = dealer
        game.hands = hands
        game.inHand = hands
        game.starter = starter
        game.turn = dealer.other
        game.phase = .play
        return game
    }
}
