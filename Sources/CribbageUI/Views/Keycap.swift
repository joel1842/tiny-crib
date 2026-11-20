import SwiftUI

struct Keycap: View {
    let label: String
    var isActive = false

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isActive ? Theme.ink : .white.opacity(0.9))
            .padding(.horizontal, 4)
            .frame(minWidth: 15, minHeight: 14)
            .glassEffect(
                isActive ? .regular.tint(Theme.gold).interactive() : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
    }
}
