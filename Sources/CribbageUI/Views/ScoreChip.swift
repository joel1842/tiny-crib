import CribbageCore
import SwiftUI

struct ScoreChip: View {
    @EnvironmentObject private var controller: GameController
    let player: Player

    var body: some View {
        let game = controller.game
        let score = controller.displayedScore(player)
        let color = Theme.color(for: player)
        let isPulsing = controller.pulses.contains(.score(player))
        let inPlay = game.phase == .play && !controller.isHoldingTable
        let isActive = inPlay && game.turn == player
        HStack(spacing: 0) {
            HStack(spacing: 3.5) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(player == .me ? "YOU" : "THEM")
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize()
                if game.dealer == player {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(color)
                        .help("\(player == .me ? "Your" : "Their") crib")
                }
            }
            Spacer(minLength: 4)
            Text("\(score)")
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.identity)
                .foregroundStyle(isPulsing ? color : .white)
        }
        .padding(.leading, 6)
        .padding(.trailing, 7)
        .frame(width: TableLayout.chipWidth, height: 22)
        .overlay(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: max(2, proxy.size.width * CGFloat(score) / CGFloat(Game.target)), height: 1.5)
                    .animation(.smooth(duration: 0.6), value: score)
            }
            .frame(height: 1.5)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
        }
        .glassEffect(.regular.tint(color.opacity(isActive || isPulsing ? 0.42 : 0.16)), in: .capsule)
        .overlay(Capsule().strokeBorder(color.opacity(isActive ? 0.8 : 0), lineWidth: 1))
        .scaleEffect(isPulsing ? 1.12 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: isActive)
    }
}
