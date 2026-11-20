import CribbageCore

extension GameController {
    var myCards: [Card] {
        game.phase == .discard ? game.hands[.me, default: []] : game.inHand[.me, default: []]
    }

    var countItems: [ScoreItem] {
        showing?.score.items ?? []
    }

    var countRows: [CountRow] {
        let revealed = countItems.prefix(countRevealed)
        return ScoreKind.allCases.compactMap { kind in
            let items = revealed.filter { $0.kind == kind }
            guard !items.isEmpty else { return nil }
            return CountRow(kind: kind, combos: items.map { $0.cards.sorted() }, points: items.reduce(0) { $0 + $1.points })
        }
    }

    var currentItem: ScoreItem? {
        let items = countItems
        guard countRevealed > 0, countRevealed <= items.count, !isCountFinished else { return nil }
        return items[countRevealed - 1]
    }

    var highlightedCards: Set<Card> {
        Set(currentItem?.cards ?? [])
    }

    var revealedPoints: Int {
        countItems.prefix(countRevealed).reduce(0) { $0 + $1.points }
    }

    var callout: String? {
        guard let item = currentItem else { return nil }
        let name = switch item.kind {
        case .fifteen: "fifteen"
        case .pair: item.points == 2 ? "pair" : item.points == 6 ? "pair royal" : "double royal"
        case .run: "run"
        case .flush: "flush"
        case .nobs: "nobs"
        case .thirtyOne: "thirty-one"
        }
        return "\(name) +\(item.points)"
    }

    func backPeg(_ player: Player) -> Int {
        game.backPegs[player] ?? 0
    }

    func displayedScore(_ player: Player) -> Int {
        heldScores?[player] ?? game.scores[player, default: 0]
    }
}
