import AppKit
import SwiftUI

@MainActor
final class AuthorizationWindowController {
    private weak var controller: AppController?
    private var panel: NSPanel?

    init(controller: AppController) {
        self.controller = controller
    }

    func show(intent: AuthorizationIntent) {
        guard let controller else { return }
        hide()

        let rootView = ExitAuthorizationView(intent: intent)
            .environmentObject(controller)
        let host = NSHostingController(rootView: rootView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = intent == .pause ? "暂停专注" : "跳过专注"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = host
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ExitAuthorizationView: View {
    let intent: AuthorizationIntent

    @EnvironmentObject private var controller: AppController
    @State private var password = ""
    @State private var isVerified = false
    @State private var amount = 5
    @State private var unit = PauseUnit.minutes

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: intent == .pause ? "pause.shield.fill" : "forward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(intent == .pause ? "暂停专注" : "跳过当前专注")
                        .font(.title2.weight(.bold))
                    Text(isVerified ? "验证通过，请选择下一步操作。" : "输入预先设置的退出密码后才能继续。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !isVerified {
                RevealablePasswordField(
                    text: $password,
                    prompt: "退出密码",
                    focusOnAppear: true,
                    onSubmit: verify
                )

                if let error = controller.authorizationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("取消") { controller.cancelAuthorization() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("验证") { verify() }
                        .buttonStyle(.borderedProminent)
                }
            } else if intent == .pause {
                HStack(spacing: 12) {
                    TextField("时长", value: $amount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Picker("单位", selection: $unit) {
                        ForEach(PauseUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack(spacing: 8) {
                    ForEach(PauseUnit.allCases) { presetUnit in
                        Button("5 \(presetUnit.title)") {
                            amount = 5
                            unit = presetUnit
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }

                HStack {
                    Button("取消") { controller.cancelAuthorization() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("确认暂停") {
                        controller.completePauseAuthorization(seconds: pauseSeconds)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pauseSeconds < 1)
                }
            } else {
                Text("跳过会让当前专注或当前限制从此刻失效。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("取消") { controller.cancelAuthorization() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("确认跳过") { controller.completeSkipAuthorization() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(26)
        .frame(minWidth: 460, minHeight: 300)
    }

    private var pauseSeconds: TimeInterval {
        let clampedAmount = max(amount, 0)
        return min(TimeInterval(clampedAmount) * unit.multiplier, 40_000_000)
    }

    private func verify() {
        if controller.verifyAuthorizationPassword(password) {
            password = ""
            isVerified = true
        }
    }
}

private enum PauseUnit: String, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seconds: return "秒"
        case .minutes: return "分钟"
        case .hours: return "小时"
        }
    }

    var multiplier: TimeInterval {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours: return 3_600
        }
    }
}
