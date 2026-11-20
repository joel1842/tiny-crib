import CribbageCore
import SwiftUI

enum BoardTrack {
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

    static func gap(after hole: Int) -> CGFloat {
        (distance(forHole: hole) + distance(forHole: hole + 1)) / 2
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
