public enum ScoreKind: Int, CaseIterable, Sendable {
    case fifteen, pair, run, flush, nobs, thirtyOne

    public var title: String {
        switch self {
        case .fifteen: "Fifteens"
        case .pair: "Pairs"
        case .run: "Runs"
        case .flush: "Flush"
        case .nobs: "Nobs"
        case .thirtyOne: "Thirty-one"
        }
    }
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
    public static func score(hand: [Card], starter: Card, isCrib: Bool) -> HandScore {
        let all = hand + [starter]
        let subsets = (1..<(1 << all.count)).map { mask in
            all.indices.filter { mask & (1 << $0) != 0 }.map { all[$0] }
        }
        var items: [ScoreItem] = []

        for subset in subsets where subset.reduce(0, { $0 + $1.value }) == 15 {
            items.append(ScoreItem(kind: .fifteen, label: ranks(subset, joinedBy: "+"), points: 2, cards: subset))
        }

        let byRank = Dictionary(grouping: all, by: \.rank).sorted { $0.key < $1.key }
        for (_, cards) in byRank where cards.count >= 2 {
            items.append(ScoreItem(kind: .pair, label: ranks(cards, joinedBy: "-"), points: cards.count * (cards.count - 1), cards: cards))
        }

        for length in stride(from: all.count, through: 3, by: -1) {
            let runs = subsets.filter { $0.count == length && isRun($0) }
            guard !runs.isEmpty else { continue }
            for run in runs {
                items.append(ScoreItem(kind: .run, label: ranks(run, joinedBy: "-"), points: length, cards: run))
            }
            break
        }

        if Set(hand.map(\.suit)).count == 1 {
            let suit = hand[0].suit.symbol
            if starter.suit == hand[0].suit {
                items.append(ScoreItem(kind: .flush, label: "5 \(suit)", points: 5, cards: hand + [starter]))
            } else if !isCrib {
                items.append(ScoreItem(kind: .flush, label: "4 \(suit)", points: 4, cards: hand))
            }
        }

        if let jack = hand.first(where: { $0.rank == 11 && $0.suit == starter.suit }) {
            items.append(ScoreItem(kind: .nobs, label: jack.description, points: 1, cards: [jack, starter]))
        }

        return HandScore(items: items)
    }

    static func ranks(_ cards: [Card], joinedBy separator: String) -> String {
        cards.sorted { $0.rank < $1.rank }.map(\.label).joined(separator: separator)
    }

    static func isRun(_ cards: [Card]) -> Bool {
        let ranks = cards.map(\.rank).sorted()
        return Set(ranks).count == ranks.count && ranks.last! - ranks.first! == ranks.count - 1
    }
}

public enum PeggingScorer {
    public static func score(sequence: [Card], count: Int) -> [ScoreItem] {
        var items: [ScoreItem] = []
        if count == 15 { items.append(ScoreItem(kind: .fifteen, label: "fifteen", points: 2)) }
        if count == 31 { items.append(ScoreItem(kind: .thirtyOne, label: "thirty-one", points: 2)) }

        guard let last = sequence.last else { return items }
        let matching = sequence.reversed().prefix { $0.rank == last.rank }.count
        if matching >= 2 {
            let name = ["", "", "pair", "pair royal", "double pair royal"][matching]
            items.append(ScoreItem(kind: .pair, label: name, points: matching * (matching - 1)))
        }

        if sequence.count >= 3 {
            for length in stride(from: sequence.count, through: 3, by: -1)
            where HandScorer.isRun(Array(sequence.suffix(length))) {
                items.append(ScoreItem(kind: .run, label: "run of \(length)", points: length))
                break
            }
        }

        return items
    }
}
