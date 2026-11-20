import CribbageCore
import SwiftUI

enum CardSize {
    case small, medium, large

    var width: CGFloat {
        switch self {
        case .small: 24
        case .medium: 32
        case .large: 40
        }
    }

    var height: CGFloat { (width * 1.4).rounded() }
}

struct PlayingCard: View, Animatable {
    let card: Card
    let size: CardSize
    var flip: Double
    var number: Int?
    var badge = 0
    var owner: Player?
    var isSelected = false
    var isDimmed = false
    var isHighlighted = false

    var animatableData: Double {
        get { flip }
        set { flip = newValue }
    }

    var body: some View {
        ZStack {
            if flip < 90 {
                CardFace(card: card, size: size, number: number, badge: badge, owner: owner, isSelected: isSelected, isDimmed: isDimmed, isHighlighted: isHighlighted)
            } else {
                CardBack(size: size)
                    .scaleEffect(x: -1)
            }
        }
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .opacity(0.3 + 0.7 * abs(cos(flip * .pi / 180)))
    }
}
