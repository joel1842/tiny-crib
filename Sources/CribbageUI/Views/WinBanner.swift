import CribbageCore
import SwiftUI

struct WinBanner: View {
    @EnvironmentObject private var controller: GameController
    let winner: Player

    var body: some View {
        let game = controller.game
        let loserScore = game.scores[winner.other, default: 0]
        let color = Theme.color(for: winner)
        HStack(spacing: 12) {
            Image(systemName: winner == .me ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 24))
                .foregroundStyle(winner == .me ? Theme.gold : Theme.bot)
                .symbolEffect(.bounce, options: .repeat(2), value: controller.celebrationStart)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(color.opacity(0.35)), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(winner == .me ? "You win" : "Bot wins")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                Text("\(game.scores[winner, default: 0]) – \(loserScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
                if loserScore < Game.skunkLine {
                    Text(loserScore < Game.doubleSkunkLine ? "Double skunk" : "Skunk")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.gold))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(color.opacity(0.22)), in: .rect(cornerRadius: 16))
    }
}
