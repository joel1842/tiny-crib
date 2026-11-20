import SwiftUI

struct GlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = cornerRadius
        view.tintColor = NSColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 0.6)
        view.appearance = NSAppearance(named: .darkAqua)

        let frost = NSVisualEffectView()
        frost.material = .hudWindow
        frost.blendingMode = .behindWindow
        frost.state = .active
        frost.appearance = NSAppearance(named: .darkAqua)
        frost.alphaValue = 0.8
        frost.wantsLayer = true
        frost.layer?.cornerRadius = cornerRadius
        frost.layer?.cornerCurve = .continuous
        frost.layer?.masksToBounds = true
        frost.autoresizingMask = [.width, .height]
        view.contentView = frost
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {}
}
