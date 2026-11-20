public enum ScoreKind: Int, CaseIterable, Sendable {
    case fifteen, pair, run, flush, nobs, thirtyOne
}

public struct ScoreItem: Equatable, Sendable {
    public let kind: ScoreKind
    public let label: String
    public let points: Int
    public var cards: [Card] = []
}

public struct HandScore: Equatable, Sendable {
    public let items: [ScoreItem]

    public var total: Int { items.reduce(0) { $0 + $1.points } }
}

public enum HandScorer {
    static let handSize = 4

    public static func score(hand: [Card], starter: Card, isCrib: Bool) -> HandScore {
        let all = hand + [starter]
        let subsets = (1..<(1 << all.count)).map { mask in
            all.indices.filter { mask & (1 << $0) != 0 }.map { all[$0] }
        }
        return HandScore(items:
            fifteens(in: subsets)
                + pairs(in: all)
                + runs(in: subsets, longest: all.count)
                + flush(hand: hand, starter: starter, isCrib: isCrib)
                + nobs(hand: hand, starter: starter)
        )
    }

    static func isRun(_ cards: [Card]) -> Bool {
        let ranks = cards.map(\.rank).sorted()
        guard let low = ranks.first, let high = ranks.last else { return false }
        return Set(ranks).count == ranks.count && high - low == ranks.count - 1
    }

    private static func fifteens(in subsets: [[Card]]) -> [ScoreItem] {
        subsets
            .filter { $0.reduce(0) { $0 + $1.value } == 15 }
            .map { ScoreItem(kind: .fifteen, label: ranks($0, joinedBy: "+"), points: 2, cards: $0) }
    }

    private static func pairs(in cards: [Card]) -> [ScoreItem] {
        Dictionary(grouping: cards, by: \.rank)
            .sorted { $0.key < $1.key }
            .filter { $0.value.count >= 2 }
            .map { _, group in
                ScoreItem(kind: .pair, label: ranks(group, joinedBy: "-"), points: group.count * (group.count - 1), cards: group)
            }
    }

    private static func runs(in subsets: [[Card]], longest: Int) -> [ScoreItem] {
        for length in stride(from: longest, through: 3, by: -1) {
            let runs = subsets.filter { $0.count == length && isRun($0) }
            if !runs.isEmpty {
                return runs.map { ScoreItem(kind: .run, label: ranks($0, joinedBy: "-"), points: length, cards: $0) }
            }
        }
        return []
    }

    private static func flush(hand: [Card], starter: Card, isCrib: Bool) -> [ScoreItem] {
        guard hand.count == handSize, let suit = hand.first?.suit, hand.allSatisfy({ $0.suit == suit }) else { return [] }
        if starter.suit == suit {
            return [ScoreItem(kind: .flush, label: "5 \(suit.symbol)", points: 5, cards: hand + [starter])]
        }
        return isCrib ? [] : [ScoreItem(kind: .flush, label: "4 \(suit.symbol)", points: 4, cards: hand)]
    }

    private static func nobs(hand: [Card], starter: Card) -> [ScoreItem] {
        guard let jack = hand.first(where: { $0.rank == Card.jack && $0.suit == starter.suit }) else { return [] }
        return [ScoreItem(kind: .nobs, label: jack.description, points: 1, cards: [jack, starter])]
    }

    private static func ranks(_ cards: [Card], joinedBy separator: String) -> String {
        cards.sorted { $0.rank < $1.rank }.map(\.label).joined(separator: separator)
    }
}

public enum PeggingScorer {
    private static let pairNames = [2: "pair", 3: "pair royal", 4: "double pair royal"]

    public static func score(sequence: [Card], count: Int) -> [ScoreItem] {
        var items: [ScoreItem] = []
        if count == 15 { items.append(ScoreItem(kind: .fifteen, label: "fifteen", points: 2)) }
        if count == Game.maxCount { items.append(ScoreItem(kind: .thirtyOne, label: "thirty-one", points: 2)) }

        guard let last = sequence.last else { return items }
        let matching = sequence.reversed().prefix { $0.rank == last.rank }.count
        if let name = pairNames[matching] {
            items.append(ScoreItem(kind: .pair, label: name, points: matching * (matching - 1)))
        }

        if let length = stride(from: sequence.count, through: 3, by: -1).first(where: { HandScorer.isRun(Array(sequence.suffix($0))) }) {
            items.append(ScoreItem(kind: .run, label: "run of \(length)", points: length))
        }

        return items
    }
}
