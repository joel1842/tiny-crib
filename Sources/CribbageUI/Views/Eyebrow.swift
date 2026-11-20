import SwiftUI

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.dim

    init(_ text: String, color: Color = Theme.dim) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(color)
    }
}
