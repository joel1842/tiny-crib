import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init(rootView: some View) {
        let hosting = NSHostingView(rootView: rootView)
        super.init(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        contentView = hosting
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
