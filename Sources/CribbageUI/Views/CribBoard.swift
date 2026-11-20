import CribbageCore
import SwiftUI

enum Oval {
    static let width: CGFloat = 310
    static let height: CGFloat = 182
    static let radius: CGFloat = 67
    static let top: CGFloat = 24
    static let leftCenter: CGFloat = 22 + radius
    static let rightCenter: CGFloat = width - 22 - radius
    static let centerY: CGFloat = top + radius
    static let mid: CGFloat = width / 2
    static let half: CGFloat = mid - leftCenter
    static let straight: CGFloat = rightCenter - leftCenter
    static let arc: CGFloat = .pi * radius
    static let perimeter: CGFloat = 2 * straight + 2 * arc
    static let lane: CGFloat = 5.5
    static let pitch: CGFloat = perimeter / (1 + 1.6 + 119 + 23 * 0.8 + 1.6)
    static let finish = CGPoint(x: mid, y: top)

    static func point(_ distance: CGFloat, _ offset: CGFloat) -> CGPoint {
        var s = distance.truncatingRemainder(dividingBy: perimeter)
        if s < 0 { s += perimeter }
        if s < half { return CGPoint(x: mid + s, y: top - offset) }
        s -= half
        if s < arc {
            let angle = -CGFloat.pi / 2 + s / radius
            return CGPoint(x: rightCenter + (radius + offset) * cos(angle), y: centerY + (radius + offset) * sin(angle))
        }
        s -= arc
        if s < straight { return CGPoint(x: rightCenter - s, y: top + 2 * radius + offset) }
        s -= straight
        if s < arc {
            let angle = CGFloat.pi / 2 + s / radius
            return CGPoint(x: leftCenter + (radius + offset) * cos(angle), y: centerY + (radius + offset) * sin(angle))
        }
        s -= arc
        return CGPoint(x: leftCenter + s, y: top - offset)
    }

    static func distance(forHole hole: Int) -> CGFloat {
        hole <= 0 ? pitch : pitch * (2.6 + CGFloat(hole - 1) + 0.8 * CGFloat((hole - 1) / 5))
    }

    static func distance(forScore score: Double) -> CGFloat {
        let low = Int(score.rounded(.down))
        let fraction = CGFloat(score - Double(low))
        return distance(forHole: low) + (distance(forHole: low + 1) - distance(forHole: low)) * fraction
    }

    static func pegPoint(_ score: Double, offset: CGFloat) -> CGPoint {
        score >= Double(Game.target) ? finish : point(distance(forScore: score), offset)
    }

    static func lanePath(from start: CGFloat, to end: CGFloat, offset: CGFloat) -> Path {
        var path = Path()
        let steps = max(2, Int(ceil((end - start) / 2)))
        for step in 0...steps {
            let p = point(start + (end - start) * CGFloat(step) / CGFloat(steps), offset)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    static func stadium(_ offset: CGFloat) -> Path {
        let r = radius + offset
        var path = Path()
        path.move(to: CGPoint(x: mid, y: top - offset))
        path.addLine(to: CGPoint(x: rightCenter, y: top - offset))
        path.addArc(center: CGPoint(x: rightCenter, y: centerY), radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: leftCenter, y: centerY + r))
        path.addArc(center: CGPoint(x: leftCenter, y: centerY), radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct CribBoard: View {
    @EnvironmentObject private var controller: GameController

    static let size = CGSize(width: Oval.width, height: Oval.height)

    var body: some View {
        let them = controller.displayedScore(.them)
        let you = controller.displayedScore(.me)
        let themBack = min(controller.backPeg(.them), them)
        let youBack = min(controller.backPeg(.me), you)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                context.stroke(Oval.stadium(0), with: .color(.black.opacity(0.32)), lineWidth: 23)
                context.stroke(Oval.stadium(0), with: .color(.white.opacity(0.035)), lineWidth: 22)
                context.stroke(Oval.stadium(11), with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                context.stroke(Oval.stadium(-11), with: .color(.white.opacity(0.07)), lineWidth: 0.5)

                for quarter in [30, 60] {
                    let s = (Oval.distance(forHole: quarter) + Oval.distance(forHole: quarter + 1)) / 2
                    var tick = Path()
                    tick.move(to: Oval.point(s, 11))
                    tick.addLine(to: Oval.point(s, -11))
                    context.stroke(tick, with: .color(.white.opacity(0.13)), lineWidth: 0.75)
                    let label = Oval.point(s, -17.5)
                    context.draw(
                        Text("\(quarter)").font(.system(size: 6.5, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.32)),
                        at: label
                    )
                }

                let skunk = (Oval.distance(forHole: 90) + Oval.distance(forHole: 91)) / 2
                var skunkLine = Path()
                skunkLine.move(to: Oval.point(skunk, 12))
                skunkLine.addLine(to: Oval.point(skunk, -12))
                context.stroke(skunkLine, with: .color(Theme.gold.opacity(0.85)), style: StrokeStyle(lineWidth: 1, lineCap: .round))

                draw(.them, front: them, back: themBack, offset: Oval.lane, in: &context)
                draw(.me, front: you, back: youBack, offset: -Oval.lane, in: &context)

                let checker = CGRect(x: Oval.mid - 1.5, y: Oval.top - 10.5, width: 3, height: 21)
                context.fill(Path(roundedRect: checker, cornerRadius: 0.5), with: .color(.white.opacity(0.75)))
                for row in stride(from: 0, to: 21, by: 3) {
                    let square = CGRect(x: Oval.mid - 1.5 + (row / 3 % 2 == 0 ? 0 : 1.5), y: Oval.top - 10.5 + CGFloat(row), width: 1.5, height: 1.5)
                    context.fill(Path(square), with: .color(Color(red: 0.06, green: 0.07, blue: 0.09)))
                }
                let finish = CGRect(x: Oval.mid - 3.75, y: Oval.top - 3.75, width: 7.5, height: 7.5)
                context.fill(Path(ellipseIn: finish), with: .color(Color(red: 0.08, green: 0.09, blue: 0.12)))
                context.stroke(Path(ellipseIn: finish), with: .color(Theme.gold), lineWidth: 1.2)
                context.fill(Path(ellipseIn: finish.insetBy(dx: 2.5, dy: 2.5)), with: .color(Theme.gold))
            }
            .frame(width: Oval.width, height: Oval.height)

            Text("121")
                .font(.system(size: 7, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gold)
                .position(x: Oval.mid, y: Oval.top + 20)
            VStack(alignment: .leading, spacing: 0) {
                Text("SKUNK")
                    .font(.system(size: 5.75, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.gold.opacity(0.85))
                Text("91")
                    .font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.gold.opacity(0.55))
            }
            .fixedSize()
            .position(x: Oval.point((Oval.distance(forHole: 90) + Oval.distance(forHole: 91)) / 2, -15).x + 12, y: Oval.centerY)

            OvalPeg(score: Double(themBack), offset: Oval.lane, color: Theme.them, isFront: false)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: themBack)
            OvalPeg(score: Double(youBack), offset: -Oval.lane, color: Theme.me, isFront: false)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: youBack)
            OvalPeg(score: Double(them), offset: Oval.lane, color: Theme.them, isFront: true)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: them)
            OvalPeg(score: Double(you), offset: -Oval.lane, color: Theme.me, isFront: true)
                .animation(.spring(duration: 0.5, bounce: 0.2), value: you)

            infield(.them, score: them, back: themBack, x: 71, alignment: .leading)
            infield(.me, score: you, back: youBack, x: Oval.width - 71, alignment: .trailing)

            let lead = abs(you - them)
            if lead > 0 {
                let leader: Player = you > them ? .me : .them
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
                .position(x: Oval.mid, y: Oval.centerY + 2)
            }

            Keycap(label: "B")
                .scaleEffect(0.85)
                .position(x: Oval.width - 24, y: Oval.height - 20)
                .onTapGesture { controller.toggleBoard() }
        }
        .frame(width: Oval.width, height: Oval.height, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func draw(_ player: Player, front: Int, back: Int, offset: CGFloat, in context: inout GraphicsContext) {
        let color = Theme.color(for: player)
        let start = Oval.distance(forHole: 0)
        let backDistance = Oval.distance(forScore: Double(back))
        let frontDistance = Oval.distance(forScore: Double(min(front, Game.target - 1)))
        if back > 0 {
            context.stroke(Oval.lanePath(from: start, to: backDistance, offset: offset), with: .color(color.opacity(0.13)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        if front > back {
            context.stroke(Oval.lanePath(from: backDistance, to: frontDistance, offset: offset), with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        let startPoint = Oval.point(start, offset)
        context.stroke(Path(ellipseIn: CGRect(x: startPoint.x - 1.5, y: startPoint.y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.35)), lineWidth: 0.65)
        for hole in 1...120 where hole != front && hole != back {
            let p = Oval.point(Oval.distance(forHole: hole), offset)
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
                if player == .me {
                    Text("YOU")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.86))
                    Circle().fill(color).frame(width: 5, height: 5)
                } else {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text("THEM")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.86))
                }
                if player == .them && isDealer { cribMark }
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
        .position(x: x, y: Oval.centerY - 4)
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

    var animatableData: Double {
        get { score }
        set { score = newValue }
    }

    var body: some View {
        let point = Oval.pegPoint(score, offset: offset)
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
