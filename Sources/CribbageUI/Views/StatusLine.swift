import CribbageCore
import SwiftUI

struct StatusLine: View {
    @EnvironmentObject private var controller: GameController

    var body: some View {
        ZStack {
            if let toast = controller.toast {
                Text(toast.text)
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 9)
                    .frame(height: 20)
                    .glassEffect(.regular.tint(toast.color.opacity(0.75)), in: .capsule)
                    .id(toast.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.4).combined(with: .opacity), removal: .identity))
            } else {
                resting
                    .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.05)), removal: .identity))
            }
        }
        .frame(width: 170, height: 22)
    }

    @ViewBuilder
    private var resting: some View {
        let game = controller.game
        if controller.showsWinner {
            hint("new game")
        } else if let showing = controller.showing {
            HStack(spacing: 5) {
                Circle().fill(Theme.color(for: showing.player)).frame(width: 5, height: 5)
                Text("\(showing.player.possessive) \(showing.isCrib ? "CRIB" : "HAND")")
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize()
                Text("\(controller.revealedPoints)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.identity)
                    .foregroundStyle(Theme.color(for: showing.player))
                    .fixedSize()
                ZStack(alignment: .leading) {
                    if let callout = controller.callout {
                        Text(callout)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gold)
                            .fixedSize()
                            .id(callout)
                            .transition(.asymmetric(insertion: .offset(y: 4).combined(with: .opacity), removal: .identity))
                    } else if controller.isCountFinished {
                        hint(showing.isCrib ? "deal" : "next")
                            .transition(.opacity)
                    }
                }
                .frame(width: 62, alignment: .leading)
            }
        } else if game.phase == .play && !controller.isHoldingTable && controller.cutStep == .done {
            let mine = game.turn == .me
            HStack(spacing: 4) {
                Circle().fill(Theme.color(for: game.turn)).frame(width: 5, height: 5)
                Text("\(game.turn.possessive) PLAY")
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(Theme.color(for: game.turn))
                    .fixedSize()
                if !mine {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(Theme.bot)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
            }
            .id(mine)
        } else if game.phase == .discard && controller.selected.count == 2 && controller.myCards.count == 6 {
            hint("to crib")
        }
    }

    private func hint(_ action: String) -> some View {
        KeyHint(key: "⏎", action: action)
            .onTapGesture { controller.pressEnter() }
    }
}
