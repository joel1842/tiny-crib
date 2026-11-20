import AppKit
import SwiftUI

struct DragHandle: View {
    var body: some View {
        Capsule()
            .fill(.white.opacity(0.4))
            .frame(width: 34, height: 4)
            .frame(width: 80, height: 12)
            .contentShape(Rectangle())
            .overlay(WindowDragArea())
            .help("Drag to move")
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.orderFrontRegardless()
            window?.makeKey()
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override var mouseDownCanMoveWindow: Bool { true }
    }
}
