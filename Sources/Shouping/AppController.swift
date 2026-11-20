import AppKit
import Combine
import CoreGraphics
import ServiceManagement
import ShoupingCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppController: ObservableObject {
    static let ownBundleIdentifier = "com.example.shouping"

    @Published private(set) var configuration: AppConfiguration
    @Published private(set) var usage: DailyUsage
    @Published private(set) var activeRestriction: ActiveRestriction?
    @Published private(set) var shieldVisible = false
    @Published private(set) var statusText = "正在启动"
    @Published private(set) var lastError: String?
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var inputMonitoringTrusted = false
    @Published private(set) var inputGateRunning = false

    var onStatusChange: (() -> Void)?

    private let configurationStore: ConfigurationStore
    private let usageStore: UsageStore
    private let ruleEngine = RuleEngine()
    private lazy var overlayController = OverlayController(controller: self)
    private lazy var inputGate = InputGate { [weak self] in
        self?.temporaryUnlock(minutes: 5)
    }

    private var tickTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var applicationObservers: [NSObjectProtocol] = []
    private var lastTick = Date()
    private var secondsSinceUsagePersist: TimeInterval = 0
    private var previewEnd: Date?
    private var cycleTracker = CycleTracker()

    init() {
        configurationStore = ConfigurationStore(fileURL: AppSupportPaths.configurationURL)
        usageStore = UsageStore(fileURL: AppSupportPaths.usageURL)
        configuration = configurationStore.load()
        usage = usageStore.daily
    }

    func start() {
        refreshPermissions()
        installWorkspaceObservers()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let tickTimer {
            RunLoop.main.add(tickTimer, forMode: .common)
        }
        tick()
    }

    func shutdown() {
        tickTimer?.invalidate()
        tickTimer = nil
        usageStore.persist()
        inputGate.stop()
        overlayController.hide()

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
        workspaceObservers.removeAll()

        let appCenter = NotificationCenter.default
        applicationObservers.forEach(appCenter.removeObserver)
        applicationObservers.removeAll()
    }

    func mutateConfiguration(_ change: (inout AppConfiguration) -> Void) {
        var next = configuration
        change(&next)
        configuration = next
        configurationStore.save(next)
        tick()
        onStatusChange?()
    }

    func startQuickFocus(minutes: Int? = nil) {
        let duration = max(minutes ?? configuration.focus.defaultFocusMinutes, 1)
        mutateConfiguration {
            $0.focusEndUnixTime = Date().addingTimeInterval(TimeInterval(duration * 60)).timeIntervalSince1970
            $0.temporaryUnlockEndUnixTime = nil
        }
        overlayController.show()
        updateInputGate(for: true)
    }

    func stopQuickFocus() {
        mutateConfiguration {
            $0.focusEndUnixTime = nil
            $0.temporaryUnlockEndUnixTime = nil
        }
        hideShield()
    }

    func temporaryUnlock(minutes: Int = 5) {
        mutateConfiguration {
            $0.temporaryUnlockEndUnixTime = Date()
                .addingTimeInterval(TimeInterval(max(minutes, 1) * 60))
                .timeIntervalSince1970
        }
        hideShield()
    }

    func previewShield() {
        previewEnd = Date().addingTimeInterval(10)
        overlayController.show()
        updateInputGate(for: false)
        tick()
    }

    func chooseAllowedApplications() {
        chooseApplications { [weak self] selected in
            guard let self else { return }
            let existing = Set(self.configuration.allowedApplications.map(\.bundleIdentifier))
            self.mutateConfiguration {
                $0.allowedApplications.append(contentsOf: selected.filter { !existing.contains($0.bundleIdentifier) })
            }
        }
    }

    func chooseLimitedApplications() {
        chooseApplications { [weak self] selected in
            guard let self else { return }
            let existing = Set(self.configuration.limitedApplications.map(\.bundleIdentifier))
            self.mutateConfiguration {
                $0.limitedApplications.append(contentsOf: selected.filter { !existing.contains($0.bundleIdentifier) })
            }
        }
    }

    func removeAllowedApplication(_ application: AppDescriptor) {
        mutateConfiguration {
            $0.allowedApplications.removeAll { $0.bundleIdentifier == application.bundleIdentifier }
        }
    }

    func removeLimitedApplication(_ application: AppDescriptor) {
        mutateConfiguration {
            $0.limitedApplications.removeAll { $0.bundleIdentifier == application.bundleIdentifier }
        }
    }

    func openApplication(_ application: AppDescriptor) {
        guard let path = application.bundlePath else {
            lastError = "无法找到 \(application.displayName) 的应用位置。"
            return
        }

        let url = URL(fileURLWithPath: path)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            Task { @MainActor in
                if let error {
                    self?.lastError = "无法打开 \(application.displayName)：\(error.localizedDescription)"
                    return
                }
                self?.hideShield()
                app?.activate()
            }
        }
    }

    func refreshPermissions() {
        accessibilityTrusted = AXIsProcessTrusted()
        inputMonitoringTrusted = CGPreflightListenEventAccess()
        inputGateRunning = inputGate.isRunning
        onStatusChange?()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissions()
    }

    func requestInputMonitoringPermission() {
        _ = CGRequestListenEventAccess()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            mutateConfiguration { $0.launchAtLogin = enabled }
        } catch {
            mutateConfiguration { $0.launchAtLogin = false }
            lastError = "无法更新自动启动设置：\(error.localizedDescription)"
        }
    }

    func setBackgroundRecovery(_ enabled: Bool) {
        let service = SMAppService.agent(plistName: "com.example.shouping.agent.plist")
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            mutateConfiguration { $0.backgroundRecovery = enabled }
        } catch {
            mutateConfiguration { $0.backgroundRecovery = false }
            lastError = "无法更新后台恢复设置：\(error.localizedDescription)"
        }
    }

    func clearUsage() {
        usageStore.clear()
        usage = usageStore.daily
        tick()
    }

    func clearError() {
        lastError = nil
    }

    var remainingText: String {
        guard let restriction = activeRestriction else {
            return "当前没有生效的限制"
        }
        if let endDate = restriction.endDate {
            let seconds = max(0, Int(endDate.timeIntervalSinceNow.rounded()))
            return Self.durationText(seconds: seconds)
        }
        return "今日额度已用完"
    }

    var remainingSeconds: Int {
        guard let endDate = activeRestriction?.endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSinceNow.rounded()))
    }

    private func installWorkspaceObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let activation = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.frontmostApplicationDidChange() }
        }
        workspaceObservers.append(activation)

        let wake = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastTick = Date()
                self?.tick()
                self?.overlayController.relayout()
            }
        }
        workspaceObservers.append(wake)

        let screens = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.overlayController.relayout() }
        }
        applicationObservers.append(screens)

        let activeSpace = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if self?.shieldVisible == true {
                    self?.overlayController.relayout()
                    self?.overlayController.orderFront()
                }
            }
        }
        workspaceObservers.append(activeSpace)
    }

    private func tick() {
        let now = Date()
        let elapsed = min(max(now.timeIntervalSince(lastTick), 0), 5)
        lastTick = now

        let rolled = usageStore.rollDayIfNeeded(now: now)
        if !rolled, !shieldVisible, elapsed > 0, isUserActive {
            recordFrontmostUsage(seconds: elapsed, now: now)
        }
        secondsSinceUsagePersist += elapsed
        if secondsSinceUsagePersist >= 15 {
            usageStore.persist()
            secondsSinceUsagePersist = 0
        }
        usage = usageStore.daily

        if let previewEnd, previewEnd > now {
            activeRestriction = ActiveRestriction(
                reason: .quickFocus,
                endDate: previewEnd,
                blockedBundleIdentifiers: [],
                allowsOnlySelectedApplications: true
            )
            showShield()
            statusText = "正在预览专注屏"
            onStatusChange?()
            return
        } else if previewEnd != nil {
            self.previewEnd = nil
            hideShield()
        }

        updateContinuousUse(elapsed: elapsed)

        let previous = activeRestriction
        var next = ruleEngine.activeRestriction(
            configuration: configuration,
            usage: usage,
            now: now
        )
        if next == nil, let cycleRestEnd = cycleTracker.restEnd, cycleRestEnd > now {
            next = ActiveRestriction(
                reason: .cycleRest,
                endDate: cycleRestEnd,
                blockedBundleIdentifiers: configuration.limitedBundleIdentifiers,
                allowsOnlySelectedApplications: false
            )
        }
        activeRestriction = next

        if next == nil {
            hideShield()
            statusText = "守屏待命"
        } else if previous == nil || previous?.reason != next?.reason {
            showShield()
            statusText = "\(next?.reason.title ?? "专注") · \(remainingText)"
        } else if !shieldVisible {
            statusText = "\(next?.reason.title ?? "专注") · 可使用允许的应用"
            frontmostApplicationDidChange()
        } else {
            statusText = "\(next?.reason.title ?? "专注") · \(remainingText)"
        }

        persistenceHygiene(now: now)
        onStatusChange?()
    }

    private func persistenceHygiene(now: Date) {
        var changed = false
        if let end = configuration.focusEndUnixTime, Date(timeIntervalSince1970: end) <= now {
            configuration.focusEndUnixTime = nil
            changed = true
        }
        if let end = configuration.temporaryUnlockEndUnixTime, Date(timeIntervalSince1970: end) <= now {
            configuration.temporaryUnlockEndUnixTime = nil
            changed = true
        }
        if changed {
            configurationStore.save(configuration)
        }
    }

    private func frontmostApplicationDidChange() {
        guard let restriction = activeRestriction else {
            hideShield()
            return
        }

        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier else {
            showShield()
            return
        }

        if bundleIdentifier == Self.ownBundleIdentifier {
            showShield()
            return
        }

        let mustBlock = ruleEngine.shouldBlockApplication(
            bundleIdentifier: bundleIdentifier,
            restriction: restriction,
            allowedBundleIdentifiers: configuration.allowedBundleIdentifiers
        )

        if mustBlock {
            if application.bundleIdentifier != "com.apple.loginwindow" {
                application.hide()
            }
            showShield()
        } else {
            hideShield()
        }
    }

    private func showShield() {
        guard activeRestriction != nil || previewEnd != nil else { return }
        shieldVisible = true
        overlayController.show()
        updateInputGate(for: true)
    }

    private func hideShield() {
        guard shieldVisible else {
            overlayController.hide()
            updateInputGate(for: false)
            return
        }
        shieldVisible = false
        overlayController.hide()
        updateInputGate(for: false)
    }

    private func updateInputGate(for shouldRun: Bool) {
        let strictRequested = shouldRun
            && configuration.focus.strength == .strict
            && configuration.focus.enforceKeyboardLock

        if strictRequested {
            if !inputGate.isRunning {
                do {
                    try inputGate.start()
                    inputGateRunning = true
                    accessibilityTrusted = AXIsProcessTrusted()
                } catch {
                    inputGateRunning = false
                    lastError = error.localizedDescription
                }
            }
        } else if inputGate.isRunning {
            inputGate.stop()
            inputGateRunning = false
        }
    }

    private var isUserActive: Bool {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null) < 90
    }

    private func recordFrontmostUsage(seconds: TimeInterval, now: Date) {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier,
              bundleIdentifier != Self.ownBundleIdentifier else { return }

        let descriptor = AppDescriptor(
            bundleIdentifier: bundleIdentifier,
            displayName: application.localizedName ?? bundleIdentifier,
            bundlePath: application.bundleURL?.path
        )
        usageStore.add(seconds: seconds, to: descriptor, now: now)
    }

    private func updateContinuousUse(elapsed: TimeInterval) {
        let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isLimitedUse = bundleIdentifier.map(configuration.limitedBundleIdentifiers.contains) ?? false
        cycleTracker.update(
            settings: configuration.cycle,
            isLimitedUse: isLimitedUse && !shieldVisible,
            isUserActive: isUserActive,
            elapsed: elapsed,
            now: Date()
        )
    }

    private func chooseApplications(completion: @escaping ([AppDescriptor]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择应用"
        panel.prompt = "添加"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK else { return }
        let selected = panel.urls.compactMap { url -> AppDescriptor? in
            guard let bundle = Bundle(url: url),
                  let identifier = bundle.bundleIdentifier else { return nil }
            let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            return AppDescriptor(
                bundleIdentifier: identifier,
                displayName: displayName,
                bundlePath: url.path
            )
        }
        completion(selected)
    }

    static func durationText(seconds: Int) -> String {
        let clamped = max(seconds, 0)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
