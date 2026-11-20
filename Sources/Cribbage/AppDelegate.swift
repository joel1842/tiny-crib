import AppKit
import Carbon.HIToolbox
import CribbageUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let originDefaultsKey = "overlayOrigin"
    private static let screenInset: CGFloat = 16

    private let controller = GameController()
    private let panel: OverlayPanel
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var menuBarItem: MenuBarItem?

    override init() {
        panel = OverlayPanel(rootView: ContentView().environmentObject(controller))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.delegate = self
        panel.setFrameOrigin(startingOrigin(for: panel.frame.size))
        panel.orderFrontRegardless()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let press = KeyPress(event)
            let handled = MainActor.assumeIsolated { self?.handle(press) ?? false }
            return handled ? nil : event
        }

        let modifiers = controlKey | optionKey
        GlobalHotKeys.register(keyCode: kVK_ANSI_C, modifiers: modifiers) { [weak self] in self?.summon() }
        GlobalHotKeys.register(keyCode: kVK_ANSI_H, modifiers: modifiers) { [weak self] in self?.toggleVisibility() }

        if let seed = demoSeed() {
            controller.runDemo(seed: seed)
        } else {
            menuBarItem = MenuBarItem(actions: .init(
                isGameVisible: { [weak self] in self?.panel.isVisible ?? false },
                toggleGame: { [weak self] in self?.toggleVisibility() },
                newGame: { [weak self] in
                    self?.show()
                    self?.controller.newGame()
                },
                toggleBoard: { [weak self] in
                    self?.show()
                    self?.controller.toggleBoard()
                }
            ))
            controller.newGame()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return false
    }

    func windowDidMove(_ notification: Notification) {
        panel.orderFrontRegardless()
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originDefaultsKey)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        rememberFrontmostApp()
        panel.orderFrontRegardless()
    }

    private func demoSeed() -> UInt64? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--demo") else { return nil }
        return arguments.dropFirst(flag + 1).first.flatMap(UInt64.init) ?? 7
    }

    private func startingOrigin(for size: NSSize) -> NSPoint {
        if let saved = UserDefaults.standard.string(forKey: Self.originDefaultsKey) {
            let origin = NSPointFromString(saved)
            let frame = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { return origin }
        }
        let screen = NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(x: screen.minX + Self.screenInset, y: screen.minY + Self.screenInset)
    }

    private func toggleVisibility() {
        panel.isVisible ? hide() : show()
    }

    private func summon() {
        panel.isKeyWindow ? dismiss() : show()
    }

    private func show() {
        rememberFrontmostApp()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func hide() {
        let wasKey = panel.isKeyWindow
        panel.orderOut(nil)
        if wasKey { previousApp?.activate() }
    }

    private func dismiss() {
        panel.resignKey()
        previousApp?.activate()
    }

    private func rememberFrontmostApp() {
        if let front = NSWorkspace.shared.frontmostApplication, front != .current {
            previousApp = front
        }
    }

    private func handle(_ press: KeyPress) -> Bool {
        if press.hasCommand {
            switch press.character {
            case "n": controller.newGame()
            case "h": hide()
            case "q": NSApp.terminate(nil)
            default: return false
            }
            return true
        }

        switch press.keyCode {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            controller.pressEnter()
        case kVK_Escape:
            dismiss()
        default:
            if press.character == "b" {
                controller.toggleBoard()
                return true
            }
            guard let number = Int(press.character), (1...6).contains(number) else { return false }
            controller.pressNumber(number)
        }
        return true
    }
}

private struct KeyPress: Sendable {
    let keyCode: Int
    let character: String
    let hasCommand: Bool

    init(_ event: NSEvent) {
        keyCode = Int(event.keyCode)
        character = event.charactersIgnoringModifiers?.lowercased() ?? ""
        hasCommand = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
    }
}
