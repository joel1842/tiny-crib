@testable import CribbageCore
import Foundation

var failures = 0
var passes = 0

@MainActor func check(_ condition: Bool, _ name: String, line: Int = #line) {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("✘ \(name) (line \(line))")
    }
}

func handScore(_ hand: [Card], _ starter: Card, crib: Bool = false) -> HandScore {
    HandScorer.score(hand: hand, starter: starter, isCrib: crib)
}

check(handScore([Card(5, .spades), Card(5, .hearts), Card(5, .diamonds), Card(11, .clubs)], Card(5, .clubs)).total == 29, "perfect 29")

let doubleDouble = handScore([Card(4, .spades), Card(4, .hearts), Card(5, .diamonds), Card(6, .clubs)], Card(6, .spades))
check(doubleDouble.total == 24, "double double run scores 24")
check(doubleDouble.items.filter { $0.kind == .run }.count == 4, "double double run lists four runs")

check(handScore([Card(2, .spades), Card(4, .hearts), Card(6, .diamonds), Card(8, .clubs)], Card(12, .spades)).total == 0, "all even cards score nothing")

let flushHand = [Card(1, .hearts), Card(3, .hearts), Card(9, .hearts), Card(13, .hearts)]
let flushInHand = handScore(flushHand, Card(7, .spades))
let flushInCrib = handScore(flushHand, Card(7, .spades), crib: true)
check(flushInHand.items.contains { $0.kind == .flush && $0.points == 4 }, "four-card flush counts in hand")
check(!flushInCrib.items.contains { $0.kind == .flush }, "four-card flush does not count in crib")
check(handScore(flushHand, Card(7, .hearts), crib: true).items.contains { $0.kind == .flush && $0.points == 5 }, "five-card flush counts in crib")

let mockup = handScore([Card(1, .spades), Card(6, .hearts), Card(7, .diamonds), Card(12, .clubs)], Card(8, .spades)).items.map(\.label)
check(mockup.contains("7+8") && mockup.contains("A+6+8") && mockup.contains("6-7-8"), "mockup hand breakdown")

check(handScore([Card(11, .hearts), Card(2, .clubs), Card(4, .clubs), Card(9, .spades)], Card(13, .hearts)).items.contains { $0.kind == .nobs && $0.label == "J♥" && $0.points == 1 && $0.cards.count == 2 }, "nobs")

check(PeggingScorer.score(sequence: [Card(10, .spades), Card(5, .hearts)], count: 15) == [ScoreItem(kind: .fifteen, label: "fifteen", points: 2)], "pegging fifteen")
check(PeggingScorer.score(sequence: [Card(13, .spades), Card(10, .hearts), Card(11, .clubs), Card(1, .hearts)], count: 31) == [ScoreItem(kind: .thirtyOne, label: "thirty-one", points: 2)], "pegging 31")
check(PeggingScorer.score(sequence: [Card(7, .spades), Card(7, .hearts), Card(7, .clubs)], count: 21) == [ScoreItem(kind: .pair, label: "pair royal", points: 6)], "pair royal")
check(PeggingScorer.score(sequence: [Card(3, .spades), Card(5, .hearts), Card(4, .clubs)], count: 12) == [ScoreItem(kind: .run, label: "run of 3", points: 3)], "out-of-order run")
check(PeggingScorer.score(sequence: [Card(4, .spades), Card(3, .hearts), Card(6, .clubs), Card(4, .hearts)], count: 17).isEmpty, "broken run scores nothing")
check(PeggingScorer.score(sequence: [Card(2, .spades), Card(3, .hearts), Card(4, .clubs), Card(2, .hearts)], count: 11) == [ScoreItem(kind: .run, label: "run of 3", points: 3)], "run in the last three cards")

var goGame = Game.atPlay(
    dealer: .bot,
    hands: [
        .me: [Card(13, .spades), Card(12, .hearts), Card(2, .clubs), Card(3, .clubs)],
        .bot: [Card(10, .spades), Card(9, .hearts), Card(4, .diamonds), Card(5, .diamonds)],
    ],
    starter: Card(1, .spades)
)
check(goGame.play(Card(13, .spades), by: .me), "pone leads")
check(goGame.play(Card(10, .spades), by: .bot), "dealer follows")
check(goGame.played.last?.points == 0, "no points for twenty")
check(!goGame.play(Card(9, .hearts), by: .me), "cannot play opponent's card")
check(goGame.play(Card(12, .hearts), by: .me), "count reaches 30")
check(goGame.scores[.me] == 1, "go point to last player")
check(goGame.played.map(\.points) == [0, 0, 1], "go point is credited to the card that earned it")

var fifteenGame = Game.atPlay(dealer: .bot, hands: [.me: [Card(10, .clubs)], .bot: [Card(5, .hearts)]], starter: Card(1, .spades))
fifteenGame.play(Card(10, .clubs), by: .me)
fifteenGame.play(Card(5, .hearts), by: .bot)
check(fifteenGame.played.map(\.points) == [0, 3], "fifteen and last card both land on the scoring card")
check(goGame.events.contains(ScoreEvent(player: .bot, points: 0, reason: .saidGo)), "opponent says go")
check(goGame.round == 1 && goGame.count == 0 && goGame.turn == .bot, "count resets and other player leads")

var overGame = Game.atPlay(
    dealer: .bot,
    hands: [.me: [Card(13, .spades), Card(5, .hearts)], .bot: [Card(10, .spades), Card(9, .hearts), Card(2, .clubs)]],
    starter: Card(1, .spades)
)
overGame.play(Card(13, .spades), by: .me)
overGame.play(Card(10, .spades), by: .bot)
overGame.play(Card(5, .hearts), by: .me)
check(!overGame.play(Card(9, .hearts), by: .bot), "play over 31 is rejected")
check(overGame.play(Card(2, .clubs), by: .bot), "legal card still plays")

var showGame = Game.atPlay(dealer: .bot, hands: [.me: [Card(2, .clubs)], .bot: [Card(3, .clubs)]], starter: Card(1, .spades))
showGame.play(Card(2, .clubs), by: .me)
showGame.play(Card(3, .clubs), by: .bot)
check(showGame.events.first == ScoreEvent(player: .bot, points: 1, reason: .lastCard), "last card point")
check(showGame.phase == .show(.pone) && showGame.showing?.player == .me, "pone counts first")
showGame.advanceShow()
check(showGame.showing?.player == .bot && showGame.showing?.isCrib == false, "dealer counts second")
showGame.advanceShow()
check(showGame.showing?.isCrib == true, "crib counts last")
showGame.advanceShow()
check(showGame.phase == .discard && showGame.dealer == .me, "deal passes after the crib")

var losingShow = Game.atPlay(dealer: .bot, hands: [.me: [Card(5, .clubs)], .bot: [Card(2, .clubs)]], starter: Card(5, .hearts))
losingShow.play(Card(5, .clubs), by: .me)
losingShow.play(Card(2, .clubs), by: .bot)
check(losingShow.winningShowing == nil, "no winning count before the target")

var winningShow = Game.atPlay(dealer: .bot, hands: [.me: [Card(5, .clubs)], .bot: [Card(2, .clubs)]], starter: Card(5, .hearts), scores: [.me: 119, .bot: 0])
winningShow.play(Card(5, .clubs), by: .me)
winningShow.play(Card(2, .clubs), by: .bot)
check(winningShow.phase == .gameOver(winner: .me), "pone wins on the count")
check(winningShow.winningShowing?.player == .me && winningShow.winningShowing?.isCrib == false, "winning count is remembered")

check([Card(9, .clubs), Card(9, .spades), Card(2, .hearts)].sorted() == [Card(2, .hearts), Card(9, .spades), Card(9, .clubs)], "cards sort by rank then suit")
check(handScore([Card(3, .hearts)], Card(9, .spades)).items.isEmpty, "a single card is not a flush")

var winsForMe = 0
for seed in UInt64(1)...60 {
    var game = Game(seed: seed)
    var steps = 0
    var rejected = 0
    while !game.isOver && steps < 5_000 {
        steps += 1
        switch game.phase {
        case .discard:
            for player in [Player.bot, .me] where game.hands[player]?.count == 6 {
                game.discard(Opponent.chooseDiscard(hand: game.hands[player, default: []], isDealer: game.dealer == player), by: player)
            }
        case .play:
            let card = Opponent.choosePlay(hand: game.inHand[game.turn, default: []], sequence: game.sequence, count: game.count)
            if card.map({ game.play($0, by: game.turn) }) != true { rejected += 1 }
        case .show:
            game.advanceShow()
        case .gameOver:
            break
        }
    }
    check(rejected == 0 && game.isOver && game.scores.values.contains(Game.target), "seed \(seed) plays a full game")
    if case .gameOver(.me) = game.phase { winsForMe += 1 }
}

print("\(passes) passed, \(failures) failed · self-play wins split \(winsForMe)/\(60 - winsForMe)")
exit(failures == 0 ? 0 : 1)
