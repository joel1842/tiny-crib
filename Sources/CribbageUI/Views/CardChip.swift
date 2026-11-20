import CribbageCore
import SwiftUI

struct CardChip: View {
    let card: Card
    var isStarter = false

    var body: some View {
        HStack(spacing: 0.5) {
            Text(card.label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .fontWidth(card.rank == 10 ? .condensed : .standard)
            Text(card.suit.symbol)
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(card.suit.isRed ? Color(red: 0.83, green: 0.13, blue: 0.23) : Theme.ink)
        .padding(.horizontal, 2.5)
        .frame(height: 13)
        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(red: 0.98, green: 0.98, blue: 0.97)))
        .overlay(alignment: .bottom) {
            if isStarter {
                Capsule()
                    .fill(Theme.gold)
                    .frame(width: 8, height: 2)
                    .offset(y: 3)
            }
        }
        .help(isStarter ? "The cut card" : "")
    }
}
