import CribbageCore
import SwiftUI

struct CribBoard: View {
    @EnvironmentObject private var controller: GameController

    static let size = CGSize(width: BoardTrack.width, height: BoardTrack.height)

    var body: some View {
        let them = controller.displayedScore(.bot)
        let you = controller.displayedScore(.me)
        let themBack = min(controller.backPeg(.bot), them)
        let youBack = min(controller.backPeg(.me), you)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                context.stroke(BoardTrack.stadium(0), with: .color(.black.opacity(0.32)), lineWidth: 23)
                context.stroke(BoardTrack.stadium(0), with: .color(.white.opacity(0.035)), lineWidth: 22)
                context.stroke(BoardTrack.stadium(11), with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                context.stroke(BoardTrack.stadium(-11), with: .color(.white.opacity(0.07)), lineWidth: 0.5)

                for quarter in [30, 60] {
                    let s = BoardTrack.gap(after: quarter)
                    var tick = Path()
                    tick.move(to: BoardTrack.point(s, 11))
                    tick.addLine(to: BoardTrack.point(s, -11))
                    context.stroke(tick, with: .color(.white.opacity(0.13)), lineWidth: 0.75)
                    let label = BoardTrack.point(s, -17.5)
                    context.draw(
                        Text("\(quarter)").font(.system(size: 6.5, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.32)),
                        at: label
                    )
                }

                let skunk = BoardTrack.gap(after: Game.skunkLine - 1)
                var skunkLine = Path()
                skunkLine.move(to: BoardTrack.point(skunk, 12))
                skunkLine.addLine(to: BoardTrack.point(skunk, -12))
                context.stroke(skunkLine, with: .color(Theme.gold.opacity(0.85)), style: StrokeStyle(lineWidth: 1, lineCap: .round))

                draw(.bot, front: them, back: themBack, offset: BoardTrack.lane, in: &context)
                draw(.me, front: you, back: youBack, offset: -BoardTrack.lane, in: &context)

                let checker = CGRect(x: BoardTrack.mid - 1.5, y: BoardTrack.top - 10.5, width: 3, height: 21)
                context.fill(Path(roundedRect: checker, cornerRadius: 0.5), with: .color(.white.opacity(0.75)))
                for row in stride(from: 0, to: 21, by: 3) {
                    let square = CGRect(x: BoardTrack.mid - 1.5 + (row / 3 % 2 == 0 ? 0 : 1.5), y: BoardTrack.top - 10.5 + CGFloat(row), width: 1.5, height: 1.5)
                    context.fill(Path(square), with: .color(Color(red: 0.06, green: 0.07, blue: 0.09)))
                }
                let finish = CGRect(x: BoardTrack.mid - 3.75, y: BoardTrack.top - 3.75, width: 7.5, height: 7.5)
                context.fill(Path(ellipseIn: finish), with: .color(Color(red: 0.08, green: 0.09, blue: 0.12)))
                context.stroke(Path(ellipseIn: finish), with: .color(Theme.gold), lineWidth: 1.2)
                context.fill(Path(ellipseIn: finish.insetBy(dx: 2.5, dy: 2.5)), with: .color(Theme.gold))
            }
            .frame(width: BoardTrack.width, height: BoardTrack.height)

            Text("121")
                .font(.system(size: 7, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gold)
                .position(x: BoardTrack.mid, y: BoardTrack.top + 20)
            VStack(alignment: .leading, spacing: 0) {
                Text("SKUNK")
                    .font(.system(size: 5.75, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.gold.opacity(0.85))
                Text("\(Game.skunkLine)")
                    .font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.gold.opacity(0.55))
            }
            .fixedSize()
            .position(x: BoardTrack.point(BoardTrack.gap(after: Game.skunkLine - 1), -15).x + 12, y: BoardTrack.centerY)

            OvalPeg(score: Double(themBack), offset: BoardTrack.lane, color: Theme.bot, isFront: false)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: themBack)
            OvalPeg(score: Double(youBack), offset: -BoardTrack.lane, color: Theme.me, isFront: false)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: youBack)
            OvalPeg(score: Double(them), offset: BoardTrack.lane, color: Theme.bot, isFront: true)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: them)
            OvalPeg(score: Double(you), offset: -BoardTrack.lane, color: Theme.me, isFront: true)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: you)

            infield(.bot, score: them, back: themBack, x: 71, alignment: .leading)
            infield(.me, score: you, back: youBack, x: BoardTrack.width - 71, alignment: .trailing)

            let lead = abs(you - them)
            if lead > 0 {
                let leader: Player = you > them ? .me : .bot
                VStack(spacing: 4) {
                    Text("+\(lead)")
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.color(for: leader))
                        .padding(.horizontal, 6)
                        .frame(height: 12)
                        .background(Capsule().fill(Theme.color(for: leader).opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Theme.color(for: leader).opacity(0.35), lineWidth: 0.5))
                    Text("LEAD")
                        .font(.system(size: 5.5, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .fixedSize()
                .position(x: BoardTrack.mid, y: BoardTrack.centerY + 2)
            }

            Keycap(label: "B")
                .scaleEffect(0.85)
                .position(x: BoardTrack.width - 24, y: BoardTrack.height - 20)
                .onTapGesture { controller.toggleBoard() }
        }
        .frame(width: BoardTrack.width, height: BoardTrack.height, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func draw(_ player: Player, front: Int, back: Int, offset: CGFloat, in context: inout GraphicsContext) {
        let color = Theme.color(for: player)
        let start = BoardTrack.distance(forHole: 0)
        let backDistance = BoardTrack.distance(forScore: Double(back))
        let frontDistance = BoardTrack.distance(forScore: Double(min(front, Game.target - 1)))
        if back > 0 {
            context.stroke(BoardTrack.lanePath(from: start, to: backDistance, offset: offset), with: .color(color.opacity(0.13)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        if front > back {
            context.stroke(BoardTrack.lanePath(from: backDistance, to: frontDistance, offset: offset), with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        let startPoint = BoardTrack.point(start, offset)
        context.stroke(Path(ellipseIn: CGRect(x: startPoint.x - 1.5, y: startPoint.y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.35)), lineWidth: 0.65)
        for hole in 1...120 where hole != front && hole != back {
            let p = BoardTrack.point(BoardTrack.distance(forHole: hole), offset)
            let size: CGFloat = hole % 5 == 0 ? 1.1 : 0.95
            let fill: Color = hole < back ? color.opacity(0.4) : hole < front ? color : .white.opacity(0.17)
            context.fill(Path(ellipseIn: CGRect(x: p.x - size, y: p.y - size, width: size * 2, height: size * 2)), with: .color(fill))
        }
    }

    private func infield(_ player: Player, score: Int, back: Int, x: CGFloat, alignment: HorizontalAlignment) -> some View {
        let color = Theme.color(for: player)
        let isDealer = controller.game.dealer == player
        return VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 4) {
                if player == .me && isDealer { cribMark }
                if player == .bot { Circle().fill(color).frame(width: 5, height: 5) }
                Text(player.name)
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.86))
                if player == .me { Circle().fill(color).frame(width: 5, height: 5) }
                if player == .bot && isDealer { cribMark }
            }
            Text("\(score)")
                .font(.system(size: 31, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.identity)
            HStack(spacing: 3) {
                Text("\(max(0, Game.target - score))")
                    .fontWeight(.heavy)
                    .foregroundStyle(.white.opacity(0.8))
                Text("to go")
                    .foregroundStyle(.white.opacity(0.45))
                if score > back {
                    Text("· +\(score - back)")
                        .foregroundStyle(color)
                }
            }
            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
        }
        .fixedSize()
        .frame(width: 0, alignment: alignment == .leading ? .leading : .trailing)
        .position(x: x, y: BoardTrack.centerY - 4)
    }

    private var cribMark: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(red: 0.25, green: 0.26, blue: 0.72))
                .overlay(RoundedRectangle(cornerRadius: 1.5, style: .continuous).strokeBorder(Color(red: 0.56, green: 0.57, blue: 1).opacity(0.7), lineWidth: 0.6))
                .frame(width: 7.5, height: 10.5)
            Text("CRIB")
                .font(.system(size: 6, weight: .heavy, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(Color(red: 0.66, green: 0.67, blue: 1))
                .fixedSize()
        }
    }
}

struct OvalPeg: View, Animatable {
    var score: Double
    let offset: CGFloat
    let color: Color
    let isFront: Bool

    nonisolated var animatableData: Double {
        get { score }
        set { score = newValue }
    }

    var body: some View {
        let point = BoardTrack.pegPoint(score, offset: offset)
        ZStack {
            if isFront {
                Circle().fill(color.opacity(0.45)).frame(width: 7, height: 7).blur(radius: 1.5)
                Circle()
                    .fill(color)
                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 0.8))
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                    .overlay(Circle().strokeBorder(color.opacity(0.8), lineWidth: 1))
                    .frame(width: 4.6, height: 4.6)
            }
        }
        .position(point)
        .allowsHitTesting(false)
    }
}
