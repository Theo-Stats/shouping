import AppKit
import Foundation
import ShoupingCore

private let mainBundleIdentifier = "com.example.shouping"

private func mainApplicationIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleIdentifier).isEmpty
}

private func launchMainApplication() throws {
    let environmentPath = ProcessInfo.processInfo.environment["SHOUPING_APP_PATH"]
    let bundleURL = environmentPath.map { URL(fileURLWithPath: $0) } ?? Bundle.main.bundleURL

    guard bundleURL.pathExtension == "app" else {
        fputs("ShoupingAgent: 无法定位守屏应用包。\n", stderr)
        exit(2)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-gj", bundleURL.path, "--args", "--background"]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        exit(process.terminationStatus)
    }
}

do {
    if mainApplicationIsRunning() {
        exit(0)
    }

    let configurationStore = ConfigurationStore(fileURL: AppSupportPaths.configurationURL)
    let usageStore = UsageStore(fileURL: AppSupportPaths.usageURL)
    let configuration = configurationStore.load()
    let restriction = RuleEngine().activeRestriction(
        configuration: configuration,
        usage: usageStore.daily,
        now: Date()
    )

    guard restriction != nil, configuration.backgroundRecovery else {
        exit(0)
    }

    try launchMainApplication()
} catch {
    fputs("ShoupingAgent: \(error.localizedDescription)\n", stderr)
    exit(1)
}
