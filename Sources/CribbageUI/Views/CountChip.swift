import CribbageCore
import SwiftUI

struct CountChip: View {
    let count: Int
    let goTag: GoTag?
    let showsLeft: Bool
    let isPulsing: Bool

    static let width: CGFloat = 92
    static let height: CGFloat = 24
    private static let barWidth: CGFloat = 76
    private static let fill = Color(red: 0.1, green: 0.11, blue: 0.16).opacity(0.94)

    var body: some View {
        let hit = count == 15 || count == 31
        let warn = count >= 25
        let progress = CGFloat(min(max(count, 0), 31)) / 31
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("COUNT")
                .font(.system(size: 7.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(count)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.identity)
                    .foregroundStyle(hit ? Theme.gold : .white)
                Text("/31")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .fixedSize()
        .offset(y: -3)
        .frame(width: Self.width, height: Self.height)
        .overlay(alignment: .bottom) {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule()
                    .fill(warn || hit ? Theme.gold : .white.opacity(0.85))
                    .frame(width: Self.barWidth * progress)
                    .animation(.easeOut(duration: 0.15), value: count)
            }
            .frame(width: Self.barWidth, height: 2)
            .padding(.bottom, 4)
        }
        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
        .overlay(alignment: .trailing) {
            status
                .alignmentGuide(.trailing) { $0[.leading] - 4 }
        }
        .scaleEffect(isPulsing ? 1.12 : 1)
    }

    @ViewBuilder private var status: some View {
        if let goTag {
            Text("\(goTag.player.name) GO")
                .font(.system(size: 7, weight: .heavy))
                .tracking(0.3)
                .foregroundStyle(Theme.ink)
                .fixedSize()
                .padding(.horizontal, 6)
                .frame(height: 14)
                .background(Capsule().fill(Theme.color(for: goTag.player)))
        } else if showsLeft && count >= 25 && count < 31 {
            Text("\(31 - count) left")
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.gold)
                .fixedSize()
                .padding(.horizontal, 6)
                .frame(height: 14)
                .background(Capsule().fill(Self.fill))
                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1))
        }
    }
}
