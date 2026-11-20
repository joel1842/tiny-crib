import CribbageCore
import SwiftUI

struct TableView: View {
    @EnvironmentObject private var controller: GameController

    private var game: Game { controller.game }
    private var size: CGSize { TableLayout.size }

    var body: some View {
        let layout = TableLayout(controller: controller)
        ZStack(alignment: .topLeading) {
            cribSlot(layout)
            ZStack(alignment: .topLeading) {
                deck(layout)
                dealCut(layout)
                cutLabel(layout)
                cards(layout)
                countChip
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            leadPlaceholder
            scoreChips
            StatusLine()
                .position(x: size.width / 2, y: layout.statusY)
                .zIndex(60)
            countRows(layout)
            winner
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func cribSlot(_ layout: TableLayout) -> some View {
        let color = Theme.color(for: game.dealer)
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(color.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .frame(width: 30, height: 40)
            .opacity(game.crib.isEmpty ? 1 : 0)
            .position(layout.cribSpot)
            .zIndex(1)
        Text("CRIB")
            .font(.system(size: 7, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(color)
            .fixedSize()
            .opacity(controller.showsWinner || controller.isCollecting || controller.showing?.isCrib == true ? 0 : 1)
            .position(x: layout.cribSpot.x, y: layout.cribSpot.y + 28)
            .zIndex(1)
    }

    @ViewBuilder
    private func deck(_ layout: TableLayout) -> some View {
        let step = controller.cutStep
        let isSplit = step.isSplit && game.starter != nil
        let isCentered = controller.dealCutStep != .done
        ForEach(0..<3, id: \.self) { layer in
            let isTop = layer == 2
            CardBack(size: .medium)
                .rotationEffect(.degrees(isTop && isSplit ? 14 : 0))
                .offset(
                    x: isTop ? (isSplit ? 26 : 0) : CGFloat(layer) - 2,
                    y: isTop ? (isSplit ? -8 : 0) : 3 - CGFloat(layer) * 1.5
                )
                .rotationEffect(.degrees(isCentered ? 0 : -360))
                .scaleEffect(isCentered ? 1.2 : 1)
                .position(layout.deckSpot)
                .zIndex(isTop ? (step == .done ? 4 : 7) : Double(layer) * 0.5)
        }
    }

    @ViewBuilder
    private func dealCut(_ layout: TableLayout) -> some View {
        let step = controller.dealCutStep
        let deck = layout.deckSpot
        if step != .done {
            ForEach([Player.bot, .me], id: \.self) { player in
                let side: CGFloat = player == .bot ? -1 : 1
                let isWinner = step == .winner && game.dealer == player
                PlayingCard(card: game.dealCut.card(for: player), size: .medium, flip: step.faceUp ? 0 : 180, isHighlighted: isWinner)
                    .rotationEffect(.degrees(step.isOut ? Double(side) * 6 : 0))
                    .scaleEffect(isWinner ? 1.15 : 1.2)
                    .position(x: deck.x + (step.isOut ? side * 62 : 0), y: deck.y - (step.isOut ? 4 : 0))
                    .zIndex(8)
                    .transition(.identity)
                if step.faceUp {
                    Text(player.name)
                        .font(.system(size: 7.5, weight: .heavy))
                        .tracking(0.7)
                        .foregroundStyle(Theme.color(for: player))
                        .fixedSize()
                        .position(x: deck.x + side * 62, y: deck.y + 34)
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func cutLabel(_ layout: TableLayout) -> some View {
        if game.starter != nil && controller.dealCutStep == .done && !controller.showsWinner && !controller.isCollecting {
            Text("CUT")
                .font(.system(size: 7, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
                .position(x: layout.deckSpot.x, y: layout.deckSpot.y + 31)
                .transition(.opacity)
        }
    }

    private func cards(_ layout: TableLayout) -> some View {
        ForEach(Array(layout.cards.enumerated()), id: \.element) { index, card in
            let spot = layout.spot(for: card)
            TimelineView(.animation(paused: !spot.bobs)) { context in
                PlayingCard(
                    card: card,
                    size: spot.size,
                    flip: spot.faceUp ? 0 : 180,
                    number: spot.number,
                    badge: spot.badge,
                    owner: spot.owner,
                    isSelected: spot.isSelected,
                    isDimmed: spot.isDimmed,
                    isHighlighted: spot.isHighlighted
                )
                .modifier(Shake(animatableData: CGFloat(controller.shakes[card, default: 0])))
                .allowsHitTesting(false)
                .rotationEffect(.degrees(spot.rotation))
                .offset(y: spot.bobs ? sin(context.date.timeIntervalSinceReferenceDate * 5 + Double(index)) * 2 : 0)
            }
            .position(spot.center)
            .zIndex(spot.z)

            if let number = spot.number {
                Color.clear
                    .frame(width: spot.size.width, height: spot.size.height + spot.lift)
                    .contentShape(Rectangle())
                    .onTapGesture { controller.pressNumber(number) }
                    .onHover { controller.hover(card, isInside: $0) }
                    .rotationEffect(.degrees(spot.rotation))
                    .position(x: spot.center.x, y: spot.center.y + spot.lift / 2)
                    .zIndex(spot.z)
            }
        }
    }

    @ViewBuilder
    private var countChip: some View {
        if (game.phase == .play && controller.cutStep == .done) || controller.isHoldingTable {
            CountChip(
                count: controller.shownCount,
                goTag: controller.goTag,
                showsLeft: game.phase == .play && (game.canPlay(.me) || game.canPlay(.bot)),
                isPulsing: controller.pulses.contains(.count)
            )
            .position(x: TableLayout.pileCenterX, y: TableLayout.chipY)
            .transition(.opacity.animation(.easeOut(duration: 0.15)))
            .zIndex(25)
        }
    }

    @ViewBuilder
    private var leadPlaceholder: some View {
        if game.phase == .play && controller.cutStep == .done && !game.played.contains(where: { $0.round >= controller.displayRound }) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: CardSize.medium.width, height: CardSize.medium.height)
                .overlay {
                    Text("\(game.turn.possessive)\nLEAD")
                        .font(.system(size: 6.5, weight: .heavy))
                        .tracking(0.4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize()
                }
                .position(x: TableLayout.pileCenterX, y: TableLayout.middleY)
                .transition(.opacity)
                .zIndex(9)
        }
    }

    @ViewBuilder
    private var scoreChips: some View {
        ForEach([Player.bot, .me], id: \.self) { player in
            ScoreChip(player: player)
                .onTapGesture { controller.toggleBoard() }
                .position(player == .me ? TableLayout.youChip : TableLayout.botChip)
                .zIndex(96)
        }
    }

    @ViewBuilder
    private func countRows(_ layout: TableLayout) -> some View {
        if let showing = controller.showing, !controller.showsWinner {
            CountRows(
                rows: controller.countRows,
                player: showing.player,
                isActive: controller.currentItem?.kind,
                isNineteen: controller.isCountFinished && showing.score.total == 0,
                starter: game.starter
            )
            .id("\(game.handNumber)-\(showing.player)-\(showing.isCrib)")
            .frame(height: layout.rowsHeight, alignment: .top)
            .position(x: size.width / 2, y: layout.rowsTop + layout.rowsHeight / 2)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.25)),
                removal: .opacity.animation(.easeIn(duration: 0.1))
            ))
            .zIndex(50)
        }
    }

    @ViewBuilder
    private var winner: some View {
        if case .gameOver(let winner) = game.phase, controller.showsWinner {
            WinBanner(winner: winner)
                .position(x: size.width / 2, y: 82)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .zIndex(70)
            if winner == .me {
                Confetti(start: controller.celebrationStart, origin: CGPoint(x: size.width / 2 - 60, y: 70))
                    .frame(width: size.width, height: size.height)
                    .zIndex(80)
            }
        }
    }
}
