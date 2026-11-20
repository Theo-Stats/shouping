import AppKit
import SwiftUI

@MainActor
final class ShieldWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayController {
    private weak var controller: AppController?
    private var windows: [NSWindow] = []

    init(controller: AppController) {
        self.controller = controller
    }

    func show() {
        guard controller != nil else { return }
        rebuildWindowsIfNeeded()

        for window in windows {
            if let screen = window.screen ?? screenMatching(window.frame) {
                window.setFrame(screen.frame, display: true)
            }
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
        }
    }

    func relayout() {
        guard !windows.isEmpty else { return }
        let screens = NSScreen.screens
        if screens.count != windows.count {
            destroyWindows()
            show()
            return
        }

        for (window, screen) in zip(windows, screens) {
            window.setFrame(screen.frame, display: true)
        }
        orderFront()
    }

    func orderFront() {
        for window in windows {
            window.orderFrontRegardless()
        }
    }

    private func rebuildWindowsIfNeeded() {
        guard let controller else { return }
        guard NSScreen.screens.count != windows.count else { return }
        destroyWindows()

        for screen in NSScreen.screens {
            let rootView = ShieldView().environmentObject(controller)
            let hostingController = NSHostingController(rootView: rootView)
            let window = ShieldWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.contentViewController = hostingController
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = false
            window.setFrame(screen.frame, display: true)
            windows.append(window)
        }
    }

    private func destroyWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func screenMatching(_ frame: NSRect) -> NSScreen? {
        NSScreen.screens.min { lhs, rhs in
            abs(lhs.frame.origin.x - frame.origin.x) + abs(lhs.frame.origin.y - frame.origin.y)
                < abs(rhs.frame.origin.x - frame.origin.x) + abs(rhs.frame.origin.y - frame.origin.y)
        }
    }
}
