import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let controller: AppController
    private let openDashboard: () -> Void
    private let statusItem: NSStatusItem
    private let statusMenuItem = NSMenuItem()

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
        menu.addItem(item(title: "临时解锁 5 分钟", action: #selector(unlockFiveMinutes)))
        menu.addItem(item(title: "结束本次专注", action: #selector(stopFocus)))
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
    }

    @objc private func startFifteenMinutes() { controller.startQuickFocus(minutes: 15) }
    @objc private func startTwentyFiveMinutes() { controller.startQuickFocus(minutes: 25) }
    @objc private func startFortyFiveMinutes() { controller.startQuickFocus(minutes: 45) }
    @objc private func previewShield() { controller.previewShield() }
    @objc private func unlockFiveMinutes() { controller.temporaryUnlock(minutes: 5) }
    @objc private func stopFocus() { controller.stopQuickFocus() }
    @objc private func showDashboard() { openDashboard() }
    @objc private func quitApplication() { controller.requestQuit() }
}
