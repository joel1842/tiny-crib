public enum Opponent {
    public static func chooseDiscard(hand: [Card], isDealer: Bool) -> [Card] {
        let unseen = Card.fullDeck.filter { !hand.contains($0) }
        var best: (discard: [Card], value: Double) = ([], -.infinity)

        for i in hand.indices {
            for j in hand.indices where j > i {
                let discard = [hand[i], hand[j]]
                let kept = hand.filter { !discard.contains($0) }
                let handTotal = unseen.reduce(0) { $0 + HandScorer.score(hand: kept, starter: $1, isCrib: false).total }
                let cribValue = estimatedCribValue(discard)
                let value = Double(handTotal) / Double(unseen.count) + (isDealer ? cribValue : -cribValue)
                if value > best.value { best = (discard, value) }
            }
        }

        return best.discard
    }

    public static func choosePlay(hand: [Card], sequence: [Card], count: Int) -> Card? {
        let legal = hand.filter { count + $0.value <= 31 }
        return legal.max { playValue($0, sequence: sequence, count: count) < playValue($1, sequence: sequence, count: count) }
    }

    static func estimatedCribValue(_ cards: [Card]) -> Double {
        let (a, b) = (cards[0], cards[1])
        var value = 0.0
        if a.rank == b.rank { value += 2 }
        if a.value + b.value == 15 { value += 2 }
        value += Double(cards.filter { $0.rank == 5 }.count)
        if a.rank != b.rank && abs(a.rank - b.rank) <= 2 { value += 0.5 }
        return value
    }

    static func playValue(_ card: Card, sequence: [Card], count: Int) -> Double {
        let newCount = count + card.value
        let points = PeggingScorer.score(sequence: sequence + [card], count: newCount).reduce(0) { $0 + $1.points }
        var value = Double(points) + Double(card.value) * 0.01

        if newCount == 5 || newCount == 21 {
            value -= 1
        } else if (1...10).contains(15 - newCount) || (1...10).contains(31 - newCount) {
            value -= 0.3
        }
        if points == 0 && newCount < 31 { value -= 0.3 }
        if count == 0 && card.value < 5 { value += 0.4 }
        if card.rank == 5 && newCount != 15 { value -= 0.4 }

        return value
    }
}
