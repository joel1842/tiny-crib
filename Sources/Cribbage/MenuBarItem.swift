import AppKit

@MainActor
final class MenuBarItem: NSObject, NSMenuDelegate {
    struct Actions {
        let isGameVisible: () -> Bool
        let toggleGame: () -> Void
        let newGame: () -> Void
        let toggleBoard: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleGame), keyEquivalent: "h")
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "suit.club.fill", accessibilityDescription: AppInfo.name)

        toggleItem.keyEquivalentModifierMask = [.control, .option]
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem(title: "New Game", action: #selector(newGame), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Crib Board", action: #selector(toggleBoard), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = actions.isGameVisible() ? "Hide Game" : "Show Game"
    }

    @objc private func toggleGame() { actions.toggleGame() }
    @objc private func newGame() { actions.newGame() }
    @objc private func toggleBoard() { actions.toggleBoard() }
}

enum AppInfo {
    static let name = "Tiny Crib"
}
