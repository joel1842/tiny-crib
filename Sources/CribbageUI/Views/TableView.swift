import CribbageCore
import SwiftUI

struct TableView: View {
    @EnvironmentObject private var controller: GameController

    var body: some View {
        let layout = TableLayout(controller: controller)
        let game = controller.game
        let size = TableLayout.size
        let step = controller.cutStep
        let isSplit = step.isSplit && game.starter != nil
        let cribColor = Theme.color(for: game.dealer)
        let deck = layout.deckSpot
        let cutStep = controller.dealCutStep
        let isCentered = cutStep != .done

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(cribColor.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: 30, height: 40)
                .opacity(game.crib.isEmpty ? 1 : 0)
                .position(layout.cribSpot)
                .zIndex(1)
            Text("CRIB")
                .font(.system(size: 7, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(cribColor)
                .fixedSize()
                .opacity(controller.showsWinner || controller.isCollecting || controller.showing?.isCrib == true ? 0 : 1)
                .position(x: layout.cribSpot.x, y: layout.cribSpot.y + 28)
                .zIndex(1)

            ZStack(alignment: .topLeading) {
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
                            .position(deck)
                            .zIndex(isTop ? (step == .done ? 4 : 7) : Double(layer) * 0.5)
                    }

                    if isCentered {
                        ForEach([Player.them, .me], id: \.self) { player in
                            let card = player == .me ? game.dealCut.me : game.dealCut.them
                            let side: CGFloat = player == .them ? -1 : 1
                            PlayingCard(
                                card: card,
                                size: .medium,
                                flip: cutStep.faceUp ? 0 : 180,
                                isHighlighted: cutStep == .winner && game.dealer == player
                            )
                            .rotationEffect(.degrees(cutStep.isOut ? Double(side) * 6 : 0))
                            .scaleEffect(cutStep == .winner && game.dealer == player ? 1.15 : 1.2)
                            .position(x: deck.x + (cutStep.isOut ? side * 62 : 0), y: deck.y - (cutStep.isOut ? 4 : 0))
                            .zIndex(8)
                            .transition(.identity)
                            if cutStep.faceUp {
                                Text(player == .me ? "YOU" : "THEM")
                                    .font(.system(size: 7.5, weight: .heavy))
                                    .tracking(0.7)
                                    .foregroundStyle(Theme.color(for: player))
                                    .fixedSize()
                                    .position(x: deck.x + side * 62, y: deck.y + 34)
                                    .transition(.opacity)
                            }
                        }
                    }

                    if game.starter != nil && !isCentered && !controller.showsWinner && !controller.isCollecting {
                        Text("CUT")
                            .font(.system(size: 7, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize()
                            .position(x: deck.x, y: deck.y + 31)
                            .transition(.opacity)
                    }

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

                if (game.phase == .play && controller.cutStep == .done) || controller.isHoldingTable {
                    CountChip(
                        count: controller.shownCount,
                        goTag: controller.goTag,
                        showsLeft: game.phase == .play && (game.canPlay(.me) || game.canPlay(.them)),
                        isPulsing: controller.pulses.contains(.count)
                    )
                    .position(x: TableLayout.pileCenterX, y: TableLayout.chipY)
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
                    .zIndex(25)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)

            if game.phase == .play || controller.isHoldingTable {
                if game.phase == .play && !game.played.contains(where: { $0.round >= controller.displayRound }) && controller.cutStep == .done {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .frame(width: CardSize.medium.width, height: CardSize.medium.height)
                        .overlay {
                            Text(game.turn == .me ? "YOUR\nLEAD" : "THEIR\nLEAD")
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

            ScoreChip(player: .them)
                .onTapGesture { controller.toggleBoard() }
                .position(TableLayout.themChip)
                .zIndex(96)
            ScoreChip(player: .me)
                .onTapGesture { controller.toggleBoard() }
                .position(TableLayout.youChip)
                .zIndex(96)
            StatusLine()
                .position(x: size.width / 2, y: layout.statusY)
                .zIndex(60)

            if let showing = controller.showing, !controller.showsWinner {
                CountRows(
                    rows: controller.countRows,
                    player: showing.player,
                    isActive: controller.currentBeat?.kind,
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
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
