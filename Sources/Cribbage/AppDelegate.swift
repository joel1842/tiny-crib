import AppKit
import Carbon.HIToolbox
import CribbageUI
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = GameController()
    private var panel: OverlayPanel!
    private var hotKeys: [HotKey] = []
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingView(rootView: ContentView().environmentObject(controller))
        let size = hosting.fittingSize

        panel = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        panel.setFrameOrigin(startingOrigin(for: size))
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let panel = self?.panel else { return }
                panel.orderFrontRegardless()
                UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: "overlayOrigin")
            }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.panelBecameKey() }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) == true ? nil : event }
        }

        let modifiers = UInt32(controlKey | optionKey)
        hotKeys = [
            HotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: modifiers) { [weak self] in
                MainActor.assumeIsolated { self?.summon() }
            },
            HotKey(keyCode: UInt32(kVK_ANSI_H), modifiers: modifiers) { [weak self] in
                MainActor.assumeIsolated { self?.toggleVisibility() }
            },
        ]

        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "--demo") {
            let seed = arguments.dropFirst(flag + 1).first.flatMap { UInt64($0) } ?? 7
            panel.orderFrontRegardless()
            controller.runDemo(seed: seed)
        } else {
            controller.newGame()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return false
    }

    private func toggleVisibility() {
        panel.isVisible ? hide() : show()
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

    private func startingOrigin(for size: NSSize) -> NSPoint {
        if let saved = UserDefaults.standard.string(forKey: "overlayOrigin") {
            let origin = NSPointFromString(saved)
            let frame = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { return origin }
        }
        let screen = NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(x: screen.minX + 16, y: screen.minY + 16)
    }

    private func panelBecameKey() {
        rememberFrontmostApp()
        panel.orderFrontRegardless()
    }

    private func rememberFrontmostApp() {
        if let front = NSWorkspace.shared.frontmostApplication, front != .current {
            previousApp = front
        }
    }

    private func summon() {
        panel.isKeyWindow ? dismiss() : show()
    }

    private func dismiss() {
        panel.resignKey()
        previousApp?.activate()
    }

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if flags.contains(.command) {
            switch key {
            case "n": controller.newGame()
            case "h": hide()
            case "q": NSApp.terminate(nil)
            default: return false
            }
            return true
        }

        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            controller.pressEnter()
        case kVK_Escape:
            dismiss()
        default:
            if key == "b" {
                controller.toggleBoard()
                return true
            }
            guard let number = Int(key), (1...6).contains(number) else { return false }
            controller.pressNumber(number)
        }
        return true
    }
}
