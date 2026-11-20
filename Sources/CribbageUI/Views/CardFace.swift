import CribbageCore
import SwiftUI

struct CardFace: View {
    let card: Card
    let size: CardSize
    var number: Int?
    var badge = 0
    var owner: Player?
    var isSelected = false
    var isDimmed = false
    var isHighlighted = false

    private static let paper = Color(red: 0.98, green: 0.98, blue: 0.97)
    private static let dimmedPaper = Color(red: 0.79, green: 0.79, blue: 0.81)
    private static let red = Color(red: 0.83, green: 0.13, blue: 0.23)
    private static let black = Color(red: 0.11, green: 0.11, blue: 0.13)

    var body: some View {
        let width = size.width
        let shape = RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
        let isTen = card.rank == 10
        let rankSize = width * 0.46
        VStack(alignment: .leading, spacing: width * 0.04) {
            Text(card.label)
                .font(.system(size: rankSize, weight: size == .small ? .heavy : .bold, design: .rounded))
                .fontWidth(isTen ? .condensed : .standard)
                .tracking(rankSize * (isTen ? -0.08 : -0.02))
                .lineLimit(1)
                .fixedSize()
            Image(systemName: symbol)
                .font(.system(size: width * 0.34, weight: .bold))
        }
        .foregroundStyle((card.suit.isRed ? Self.red : Self.black).opacity(isDimmed ? 0.7 : 1))
        .padding(.leading, width * 0.12)
        .padding(.top, width * 0.08)
        .frame(width: width, height: size.height, alignment: .topLeading)
        .background(shape.fill(isDimmed ? Self.dimmedPaper : Self.paper))
        .overlay(shape.strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
        .overlay {
            if let ring {
                shape.inset(by: -1).stroke(ring, lineWidth: 1.5)
            }
        }
        .overlay(alignment: .bottomTrailing) { number.map(keyBadge) }
        .overlay(alignment: .topTrailing) { scoreBadge.offset(x: width * 0.1, y: width * 0.1) }
        .shadow(color: isSelected || isHighlighted ? Theme.gold.opacity(0.75) : .black.opacity(0.35), radius: isSelected || isHighlighted ? 7 : 2, y: isSelected || isHighlighted ? 0 : 1)
    }

    private var symbol: String {
        switch card.suit {
        case .spades: "suit.spade.fill"
        case .hearts: "suit.heart.fill"
        case .diamonds: "suit.diamond.fill"
        case .clubs: "suit.club.fill"
        }
    }

    private var ring: Color? {
        if isSelected || isHighlighted { return Theme.gold }
        if let owner { return Theme.color(for: owner) }
        return nil
    }

    @ViewBuilder
    private var scoreBadge: some View {
        if badge > 0, let owner {
            let width = size.width
            Text("+\(badge)")
                .font(.system(size: max(7.5, width * 0.22), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, width * 0.08)
                .frame(minHeight: max(11, width * 0.34))
                .background(Capsule().fill(Theme.color(for: owner)))
                .overlay(Capsule().strokeBorder(Self.paper, lineWidth: 1.5))
                .transition(.asymmetric(insertion: .scale(scale: 0.2).animation(.spring(duration: 0.4, bounce: 0.6).delay(0.3)), removal: .identity))
        }
    }

    private func keyBadge(_ number: Int) -> some View {
        let width = size.width
        return Text("\(number)")
            .font(.system(size: max(7.5, width * 0.24), weight: .bold, design: .rounded))
            .foregroundStyle(isSelected ? Theme.ink : .white)
            .frame(width: max(11, width * 0.36), height: max(11, width * 0.36))
            .background(Circle().fill(isSelected ? Theme.gold : Color(red: 0.16, green: 0.16, blue: 0.19)))
            .padding(width * 0.07)
    }
}
