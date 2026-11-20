import SwiftUI

struct Confetti: View {
    let start: Date
    let origin: CGPoint
    private let symbols = ["♠", "♥", "♦", "♣", "★"]
    private let colors: [Color] = [Theme.gold, Theme.me, Theme.bot, .white, Theme.suitRed]
    private let lifetime = 2.6

    var body: some View {
        TimelineView(.animation(paused: Date().timeIntervalSince(start) > lifetime)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            Canvas { canvas, _ in
                guard elapsed < lifetime else { return }
                for index in 0..<42 {
                    let a = noise(index, 1), b = noise(index, 2), c = noise(index, 3)
                    let angle = -.pi / 2 + (a - 0.5) * 2.2
                    let speed = 110 + b * 150
                    let x = origin.x + cos(angle) * speed * elapsed
                    let y = origin.y + sin(angle) * speed * elapsed + 0.5 * 260 * elapsed * elapsed
                    var symbol = canvas.resolve(
                        Text(symbols[index % symbols.count])
                            .font(.system(size: 8 + c * 8, weight: .bold))
                            .foregroundStyle(colors[index % colors.count])
                    )
                    symbol.shading = .color(colors[index % colors.count])
                    canvas.opacity = max(0, 1 - elapsed / lifetime)
                    canvas.drawLayer { layer in
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: .radians(elapsed * (c - 0.5) * 10))
                        layer.draw(symbol, at: .zero)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func noise(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index * 97 + salt * 31) * 12.9898) * 43758.5453
        return value - value.rounded(.down)
    }
}
