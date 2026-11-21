import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let controller: AppController
    private let openDashboard: () -> Void
    private let statusItem: NSStatusItem
    private let statusMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem()
    private let skipMenuItem = NSMenuItem()

    init(controller: AppController, openDashboard: @escaping () -> Void) {
        self.controller = controller
        self.openDashboard = openDashboard
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureMenu()
        controller.onStatusChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func configureMenu() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "守屏")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        menu.addItem(item(title: "专注 15 分钟", action: #selector(startFifteenMinutes)))
        menu.addItem(item(title: "专注 25 分钟", action: #selector(startTwentyFiveMinutes)))
        menu.addItem(item(title: "专注 45 分钟", action: #selector(startFortyFiveMinutes)))
        menu.addItem(.separator())
        menu.addItem(item(title: "预览专注屏（10 秒）", action: #selector(previewShield)))
        configure(pauseMenuItem, title: "暂停 5 分钟", action: #selector(pauseFiveMinutes))
        configure(skipMenuItem, title: "跳过当前专注", action: #selector(skipCurrentRestriction))
        menu.addItem(pauseMenuItem)
        menu.addItem(skipMenuItem)
        menu.addItem(.separator())
        menu.addItem(item(title: "打开守屏…", action: #selector(showDashboard)))
        menu.addItem(item(title: "退出守屏", action: #selector(quitApplication)))

        statusItem.menu = menu
    }

    private func item(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func configure(_ item: NSMenuItem, title: String, action: Selector) {
        item.title = title
        item.action = action
        item.target = self
    }

    private func refresh() {
        statusMenuItem.title = controller.statusText
        let symbol: String
        if controller.shieldVisible {
            symbol = "shield.fill"
        } else if controller.configuration.temporaryUnlockEndUnixTime.map({ Date(timeIntervalSince1970: $0) > Date() }) == true {
            symbol = "pause.circle.fill"
        } else if controller.activeRestriction != nil {
            symbol = "shield.lefthalf.filled"
        } else {
            symbol = "shield"
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "守屏")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = controller.statusText
        pauseMenuItem.isEnabled = controller.canPauseCurrentRestriction
        skipMenuItem.isEnabled = controller.canSkipCurrentRestriction
    }

    @objc private func startFifteenMinutes() { controller.startQuickFocus(minutes: 15) }
    @objc private func startTwentyFiveMinutes() { controller.startQuickFocus(minutes: 25) }
    @objc private func startFortyFiveMinutes() { controller.startQuickFocus(minutes: 45) }
    @objc private func previewShield() { controller.previewShield() }
    @objc private func pauseFiveMinutes() { controller.requestPauseAuthorization() }
    @objc private func skipCurrentRestriction() { controller.requestSkipAuthorization() }
    @objc private func showDashboard() { openDashboard() }
    @objc private func quitApplication() { controller.requestQuit() }
}
