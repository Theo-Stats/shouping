import AppKit
import SwiftUI

@MainActor
final class CycleReminderWindowController: NSObject, NSWindowDelegate {
    private weak var controller: AppController?
    private var panel: NSPanel?

    init(controller: AppController) {
        self.controller = controller
        super.init()
    }

    func show(useMinutes: Int) {
        guard let controller else { return }
        hide()

        let rootView = ContinuousUseReminderView(
            useMinutes: useMinutes,
            onDecline: { [weak controller] in controller?.declineCycleReminder() },
            onStart: { [weak controller] minutes in
                controller?.startCycleReminderRest(minutes: minutes)
            }
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 400),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "休息提醒"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        controller?.declineCycleReminder()
    }
}

private struct ContinuousUseReminderView: View {
    private enum Stage {
        case question
        case chooseDuration
    }

    let useMinutes: Int
    let onDecline: () -> Void
    let onStart: (Int) -> Void

    @State private var stage: Stage = .question
    @State private var customMinutes = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if stage == .question {
                questionView
                    .transition(.opacity)
            } else {
                durationView
                    .transition(.opacity)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.18), value: stage)
    }

    private var questionView: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("休息一下吧")
                        .font(.title2.weight(.bold))
                    Text("连续使用 \(useMinutes) 分钟了。起身走一走、看看远处，让接下来的时间更从容。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("让生活更有意义，也给注意力一点恢复的时间。")
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.8))

            Spacer()

            HStack(spacing: 12) {
                Spacer()
                Button("否", action: onDecline)
                    .keyboardShortcut(.cancelAction)
                Button("是，休息一下") {
                    stage = .chooseDuration
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var durationView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("选择休息时间")
                    .font(.title2.weight(.bold))
                Text("休息时会进入守屏，帮助你真正离开屏幕。")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                durationCard(minutes: 30, title: "30 分钟", symbol: "leaf.fill")
                durationCard(minutes: 60, title: "1 小时", symbol: "cloud.sun.fill")
                durationCard(minutes: 120, title: "2 小时", symbol: "moon.stars.fill")
            }

            Divider()

            HStack(spacing: 10) {
                Text("自定义")
                TextField("分钟", value: customMinutesBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 74)
                Text("分钟")
                    .foregroundStyle(.secondary)
                Stepper("", value: customMinutesBinding, in: 1...1_440)
                    .labelsHidden()
                Spacer()
                Button("开始休息") { onStart(customMinutes) }
                    .buttonStyle(.borderedProminent)
            }

            Spacer()

            HStack {
                Button("返回") { stage = .question }
                Spacer()
                Text("可设置 1 分钟–24 小时")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func durationCard(minutes: Int, title: String, symbol: String) -> some View {
        Button {
            onStart(minutes)
        } label: {
            VStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(.teal)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var customMinutesBinding: Binding<Int> {
        Binding(
            get: { min(max(customMinutes, 1), 1_440) },
            set: { customMinutes = min(max($0, 1), 1_440) }
        )
    }
}
