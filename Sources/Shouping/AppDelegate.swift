import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private var menuBarController: MenuBarController?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = AppController()
        self.controller = controller
        controller.start()

        menuBarController = MenuBarController(
            controller: controller,
            openDashboard: { [weak self] in self?.showMainWindow() }
        )

        if !ProcessInfo.processInfo.arguments.contains("--background"),
           controller.activeRestriction == nil {
            showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller, controller.canTerminateApplication else {
            controller?.requestQuit()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        controller?.applicationDidBecomeActive()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func showMainWindow() {
        guard let controller else { return }

        if mainWindow == nil {
            let rootView = MainView().environmentObject(controller)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "守屏"
            window.setContentSize(NSSize(width: 820, height: 620))
            window.minSize = NSSize(width: 720, height: 520)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            mainWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
