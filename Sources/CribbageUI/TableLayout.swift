import CribbageCore
import SwiftUI

struct CardSpot {
    var center: CGPoint
    var size: CardSize
    var faceUp: Bool
    var z: Double
    var rotation: Double = 0
    var number: Int?
    var isSelected = false
    var isDimmed = false
    var isHighlighted = false
    var badge = 0
    var owner: Player?
    var bobs = false
    var lift: CGFloat = 0
}

@MainActor
struct TableLayout {
    static let size = CGSize(width: 290, height: 162)
    static let stripY: CGFloat = 10
    static let chipWidth: CGFloat = 90
    static let botChip = CGPoint(x: chipWidth / 2, y: stripY)
    static let youChip = CGPoint(x: size.width - chipWidth / 2, y: stripY)
    static let statusY: CGFloat = 33
    static let middleY: CGFloat = 70
    static let chipY: CGFloat = 108
    static let fanY: CGFloat = 4
    static let deck = CGPoint(x: 20, y: middleY)
    static let crib = CGPoint(x: size.width - 20, y: middleY)
    static let handY: CGFloat = size.height - 16
    static let pileCenterX: CGFloat = size.width / 2 + 4
    static let showTop: CGFloat = 22
    static let showBottom: CGFloat = 164
    static let titleHeight: CGFloat = 18
    static let rowHeight: CGFloat = 14
    static let rowSpacing: CGFloat = 2

    let controller: GameController
    private var game: Game { controller.game }

    var deckSpot: CGPoint {
        controller.dealCutStep == .done ? CGPoint(x: Self.deck.x, y: rowY) : CGPoint(x: Self.size.width / 2, y: Self.middleY + 8)
    }

    var cribSpot: CGPoint {
        CGPoint(x: Self.crib.x, y: rowY)
    }

    private var isShowing: Bool {
        controller.showing != nil && !controller.showsWinner
    }

    var rowsHeight: CGFloat {
        let count = CGFloat(max(1, Set(controller.countItems.map(\.kind)).count))
        return count * Self.rowHeight + (count - 1) * Self.rowSpacing
    }

    private var showGap: CGFloat {
        max(0, (Self.showBottom - Self.showTop - Self.titleHeight - CardSize.medium.height - rowsHeight) / 4)
    }

    var statusY: CGFloat {
        isShowing ? Self.showTop + showGap + Self.titleHeight / 2 : Self.statusY
    }

    var rowY: CGFloat {
        isShowing ? Self.showTop + showGap * 2 + Self.titleHeight + CardSize.medium.height / 2 : Self.middleY
    }

    var rowsTop: CGFloat {
        Self.showTop + showGap * 3 + Self.titleHeight + CardSize.medium.height
    }

    var cards: [Card] {
        var all = game.hands[.bot, default: []] + game.hands[.me, default: []] + game.crib
        if let starter = game.starter { all.append(starter) }
        return all
    }

    func spot(for card: Card) -> CardSpot {
        if controller.isCollecting || controller.showsWinner {
            return CardSpot(center: deckSpot, size: .medium, faceUp: false, z: 0.2)
        }
        let isCounting = controller.currentItem != nil
        if card == game.starter {
            let step = controller.cutStep
            let isHighlighted = controller.highlightedCards.contains(card)
            return CardSpot(
                center: CGPoint(x: deckSpot.x, y: deckSpot.y - (step.lifted ? 8 : 0) - (isHighlighted ? 6 : 0)),
                size: .medium,
                faceUp: controller.showing != nil || step.showsFace,
                z: 6,
                isDimmed: isCounting && !isHighlighted,
                isHighlighted: isHighlighted
            )
        }
        if let showing = controller.showing, let index = showing.cards.sorted().firstIndex(of: card) {
            let isHighlighted = controller.highlightedCards.contains(card)
            return CardSpot(
                center: CGPoint(x: Self.size.width / 2 - 60 + CGFloat(index) * 40, y: rowY - (isHighlighted ? 5 : 0)),
                size: .medium,
                faceUp: true,
                z: 40 + Double(index),
                isDimmed: isCounting && !isHighlighted,
                isHighlighted: isHighlighted
            )
        }
        if let index = game.crib.firstIndex(of: card) {
            return CardSpot(
                center: CGPoint(x: cribSpot.x + CGFloat(index) * 1.5, y: cribSpot.y - CGFloat(index) * 1.5),
                size: .small,
                faceUp: false,
                z: 2 + Double(index)
            )
        }

        let owner: Player = game.hands[.me, default: []].contains(card) ? .me : .bot
        if game.phase == .discard {
            let hand = game.hands[owner, default: []]
            let index = hand.firstIndex(of: card) ?? 0
            let dealIndex = index * 2 + (owner == game.dealer ? 1 : 0)
            if dealIndex >= controller.dealtCount {
                return CardSpot(center: deckSpot, size: .medium, faceUp: false, z: 0.2)
            }
            return owner == .me ? myHand(index: index, count: hand.count, card: card) : theirHand(index: index, count: hand.count)
        }
        if controller.showing != nil {
            return CardSpot(center: hiddenSpot(owner), size: .small, faceUp: false, z: 0.5)
        }
        if let index = game.played.firstIndex(where: { $0.card == card }) {
            let entry = game.played[index]
            let current = game.played.filter { $0.round >= controller.displayRound }
            if entry.round < controller.displayRound {
                let stacked = game.played.filter { $0.round < controller.displayRound }
                let position = stacked.firstIndex(of: entry) ?? 0
                return CardSpot(
                    center: CGPoint(x: 55 + CGFloat(position) * 3, y: Self.middleY + 6),
                    size: .small,
                    faceUp: true,
                    z: 8 + Double(position) * 0.1,
                    isDimmed: true,
                    owner: entry.player
                )
            }
            let position = CGFloat(current.firstIndex(of: entry) ?? 0)
            let stride: CGFloat = current.count >= 6 ? 21 : 24
            return CardSpot(
                center: CGPoint(
                    x: Self.pileCenterX + (position - CGFloat(current.count - 1) / 2) * stride,
                    y: Self.middleY + (entry.player == .bot ? -2 : 2)
                ),
                size: .medium,
                faceUp: true,
                z: 10 + Double(index),
                rotation: Double((card.rank * 7 + card.suit.rawValue * 13) % 5 - 2) * 0.8,
                badge: entry.points,
                owner: entry.player
            )
        }
        if owner == .bot {
            let hand = game.inHand[.bot, default: []]
            return theirHand(index: hand.firstIndex(of: card) ?? 0, count: hand.count)
        }
        let hand = game.inHand[.me, default: []]
        return myHand(index: hand.firstIndex(of: card) ?? 0, count: hand.count, card: card)
    }

    private func theirHand(index: Int, count: Int) -> CardSpot {
        let degrees = (Double(index) - Double(count - 1) / 2) * 6
        let radians = degrees * .pi / 180
        let radius = 123.0
        return CardSpot(
            center: CGPoint(
                x: Self.size.width / 2 + radius * sin(radians),
                y: Self.fanY + radius * (cos(radians) - 1)
            ),
            size: .small,
            faceUp: false,
            z: 20 + Double(index),
            rotation: -degrees,
            bobs: game.phase == .play && game.turn == .bot && !controller.isHoldingTable
        )
    }

    private func hiddenSpot(_ owner: Player) -> CGPoint {
        let chip = owner == .me ? Self.youChip : Self.botChip
        return CGPoint(x: chip.x, y: chip.y - 48)
    }

    private func myHand(index: Int, count: Int, card: Card) -> CardSpot {
        let offset = CGFloat(index) - CGFloat(count - 1) / 2
        let isDiscarding = game.phase == .discard
        let isSelected = isDiscarding && controller.selected.contains(index)
        let myTurn = game.phase == .play && game.turn == .me
        let isPlayable = myTurn && game.count + card.value <= 31
        let lift = (isSelected ? 14 : 0) + (controller.hoveredCard == card && (isDiscarding || isPlayable) ? 6 : 0) + (isPlayable ? 3 : 0)
        let spacing: CGFloat = count >= 5 ? 33 : 37
        return CardSpot(
            center: CGPoint(x: Self.size.width / 2 + offset * spacing, y: Self.handY + abs(offset) * 1.2 - CGFloat(lift)),
            size: .medium,
            faceUp: true,
            z: 30 + Double(index) + (isSelected ? 10 : 0),
            rotation: Double(offset) * 2.5,
            number: index + 1,
            isSelected: isSelected,
            isDimmed: myTurn && !isPlayable,
            lift: CGFloat(lift)
        )
    }
}
