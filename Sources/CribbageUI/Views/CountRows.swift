import CribbageCore
import SwiftUI

struct CountRows: View {
    let rows: [CountRow]
    let player: Player
    let isActive: ScoreKind?
    let isNineteen: Bool
    let starter: Card?

    var body: some View {
        VStack(spacing: TableLayout.rowSpacing) {
            if isNineteen {
                Text("nineteen")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
            ForEach(rows) { row in
                let active = row.kind == isActive
                HStack(spacing: 5) {
                    Text(label(row.kind))
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, alignment: .leading)
                    ViewThatFits(in: .horizontal) {
                        ForEach(Array(stride(from: row.combos.count, through: 1, by: -1)), id: \.self) { shown in
                            HStack(spacing: 5) {
                                ForEach(Array(row.combos.prefix(shown).enumerated()), id: \.offset) { _, combo in
                                    HStack(spacing: 1) {
                                        ForEach(combo, id: \.self) { card in
                                            CardChip(card: card, isStarter: card == starter)
                                        }
                                    }
                                    .fixedSize()
                                }
                                if row.combos.count > shown {
                                    Text("+\(row.combos.count - shown)")
                                        .fixedSize()
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.points)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.color(for: player))
                        .frame(width: 16, alignment: .trailing)
                }
                .padding(.horizontal, 6)
                .frame(height: TableLayout.rowHeight)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? Theme.gold.opacity(0.22) : .white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(active ? 0.6 : 0), lineWidth: 1)
                )
                .transition(.offset(y: -8).combined(with: .opacity))
            }
        }
        .frame(width: 214, alignment: .top)
    }

    private func label(_ kind: ScoreKind) -> String {
        switch kind {
        case .fifteen: "15s"
        case .pair: "Pairs"
        case .run: "Run"
        case .flush: "Flush"
        case .nobs: "Nobs"
        case .thirtyOne: "31"
        }
    }
}
