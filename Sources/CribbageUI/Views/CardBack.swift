import SwiftUI

struct CardBack: View {
    let size: CardSize

    var body: some View {
        let width = size.width
        let shape = RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
        shape
            .fill(LinearGradient(
                colors: [Color(red: 0.29, green: 0.31, blue: 0.66), Color(red: 0.24, green: 0.26, blue: 0.56)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
                    .padding(width * 0.08)
            )
            .overlay(shape.strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
            .frame(width: width, height: size.height)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}
