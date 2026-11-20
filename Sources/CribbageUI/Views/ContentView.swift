import CribbageCore
import SwiftUI

public struct ContentView: View {
    @EnvironmentObject private var controller: GameController

    public init() {}

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack {
            if controller.isBoardShown {
                CribBoard()
                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .identity))
            } else {
                TableView()
                    .padding(10)
                    .transition(.identity)
            }
        }
            .background(GlassBackground(cornerRadius: 20))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .overlay(alignment: .top) {
                DragHandle()
            }
            .environment(\.colorScheme, .dark)
            .environment(\.controlActiveState, .key)
            .fixedSize()
    }
}
