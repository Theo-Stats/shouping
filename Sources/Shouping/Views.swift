import AppKit
import ShoupingCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("今天", systemImage: "sun.max") }
            RulesView()
                .tabItem { Label("规则", systemImage: "slider.horizontal.3") }
            ApplicationsView()
                .tabItem { Label("应用", systemImage: "square.grid.2x2") }
            UsageView()
                .tabItem { Label("记录", systemImage: "chart.bar") }
            PrivacyView()
                .tabItem { Label("权限", systemImage: "lock.shield") }
        }
        .padding(.top, 8)
        .frame(minWidth: 720, minHeight: 520)
        .overlay(alignment: .top) {
            if let error = controller.lastError {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                    Button("知道了") { controller.clearError() }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var controller: AppController
    @State private var customMinutes = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                quickStartCard
                currentStateCard
                if controller.configuration.focus.enforceKeyboardLock,
                   (!controller.accessibilityTrusted || !controller.inputMonitoringTrusted) {
                    permissionWarningCard
                }
                safetyCard
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("守屏")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("把时间留给重要的事。所有使用数据默认只保存在这台 Mac。")
                .foregroundStyle(.secondary)
        }
    }

    private var quickStartCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("快速专注", systemImage: "hourglass")
                    .font(.headline)
                Text("进入专注后，非白名单应用会被遮挡。允许的应用可以从专注屏直接打开。")
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach([15, 25, 45], id: \.self) { minutes in
                        Button {
                            controller.startQuickFocus(minutes: minutes)
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(minutes)")
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                Text("分钟")
                                    .font(.caption)
                            }
                            .frame(minWidth: 92, minHeight: 64)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Button("预览专注屏") { controller.previewShield() }
                        .buttonStyle(.bordered)
                }

                Divider()

                HStack(spacing: 10) {
                    Text("自定义")
                    TextField("分钟", value: $customMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("分钟")
                        .foregroundStyle(.secondary)
                    Stepper("", value: $customMinutes, in: 1...720)
                        .labelsHidden()
                    Button("开始自定义专注") {
                        controller.startQuickFocus(minutes: customMinutes)
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    Text("可设置 1–720 分钟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var currentStateCard: some View {
        GroupBox {
            HStack(spacing: 18) {
                Image(systemName: controller.shieldVisible ? "shield.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 38))
                    .foregroundStyle(controller.activeRestriction == nil ? Color.secondary : Color.accentColor)
                VStack(alignment: .leading, spacing: 5) {
                    Text(controller.statusText)
                        .font(.title3.weight(.semibold))
                    Text(controller.detailText)
                        .font(.system(.title2, design: .monospaced, weight: .medium))
                }
                Spacer()
                if controller.activeRestriction != nil {
                    HStack {
                        if controller.canPauseCurrentRestriction {
                            Button("暂停…") { controller.requestPauseAuthorization() }
                                .buttonStyle(.bordered)
                        }
                        if controller.canSkipCurrentRestriction {
                            Button("跳过…") { controller.requestSkipAuthorization() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var safetyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("恢复与绕过边界", systemImage: "arrow.uturn.backward.circle")
                    .font(.headline)
                Text("暂停与跳过会按你的规则决定是否开放。暂停只解除 5 分钟；跳过会结束当前专注或让当前时段失效到自然结束。普通 Mac 应用无法可靠阻止管理员删除应用、清空数据或使用“强制退出”，这些操作会直接显示为可见绕过。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
        }
    }

    private var permissionWarningCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.lock.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("强制键盘拦截尚未生效")
                        .font(.headline)
                    Text("当前仍会使用全屏遮挡，但键盘没有被拦截。请打开“权限”页完成检测。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
        }
    }
}

private struct RulesView: View {
    @EnvironmentObject private var controller: AppController
    @State private var showingPasswordSetup = false
    @State private var confirmingPasswordRemoval = false

    var body: some View {
        Form {
            Section("专注强度") {
                Picker(
                    "默认方式",
                    selection: Binding(
                        get: { controller.configuration.focus.strength },
                        set: { value in controller.mutateConfiguration { $0.focus.strength = value } }
                    )
                ) {
                    ForEach(InterventionStrength.allCases) { strength in
                        Text(strength.title).tag(strength)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(
                    "默认专注时长：\(controller.configuration.focus.defaultFocusMinutes) 分钟",
                    value: Binding(
                        get: { controller.configuration.focus.defaultFocusMinutes },
                        set: { value in controller.mutateConfiguration { $0.focus.defaultFocusMinutes = value } }
                    ),
                    in: 5...180,
                    step: 5
                )

                Toggle(
                    "强制模式同时拦截键盘输入",
                    isOn: Binding(
                        get: { controller.configuration.focus.enforceKeyboardLock },
                        set: { value in controller.mutateConfiguration { $0.focus.enforceKeyboardLock = value } }
                    )
                )
                Text("只在专注屏显示时生效；不记录按键内容。需要额外系统权限。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("暂停与跳过") {
                Toggle(
                    "允许暂停 5 分钟",
                    isOn: Binding(
                        get: { controller.configuration.focus.controls.allowPause },
                        set: { value in controller.mutateConfiguration { $0.focus.controls.allowPause = value } }
                    )
                )
                Toggle(
                    "允许跳过当前专注",
                    isOn: Binding(
                        get: { controller.configuration.focus.controls.allowSkip },
                        set: { value in controller.mutateConfiguration { $0.focus.controls.allowSkip = value } }
                    )
                )
                Text("关闭后，对应的遮罩按钮、菜单项和紧急快捷键都会失效。两项都关闭时，只能等待规则自然结束，或使用系统级强制退出。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: controller.hasExitPassword ? "key.fill" : "key.slash")
                        .foregroundStyle(controller.hasExitPassword ? .green : .orange)
                    Text(controller.hasExitPassword ? "退出密码已设置" : "尚未设置退出密码")
                    Spacer()
                    Button(controller.hasExitPassword ? "修改密码" : "设置密码") {
                        showingPasswordSetup = true
                    }
                    if controller.hasExitPassword {
                        Button("移除", role: .destructive) {
                            confirmingPasswordRemoval = true
                        }
                    }
                }
                Text("密码保存在 macOS Keychain。未设置密码时，暂停和跳过入口不会出现。密码无法找回，只能移除后重设。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("定时专注") {
                Toggle(
                    "启用定时规则",
                    isOn: Binding(
                        get: { controller.configuration.schedule.isEnabled },
                        set: { value in controller.mutateConfiguration { $0.schedule.isEnabled = value } }
                    )
                )

                HStack(spacing: 18) {
                    ScheduleTimePicker(
                        title: "开始",
                        minutes: Binding(
                            get: { controller.configuration.schedule.startMinutes },
                            set: { value in controller.mutateConfiguration { $0.schedule.startMinutes = value } }
                        )
                    )
                    ScheduleTimePicker(
                        title: "结束",
                        minutes: Binding(
                            get: { controller.configuration.schedule.endMinutes },
                            set: { value in controller.mutateConfiguration { $0.schedule.endMinutes = value } }
                        )
                    )
                }

                Text("生效日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { index, name in
                        let weekday = index + 1
                        let selected = controller.configuration.schedule.activeWeekdays.contains(weekday)
                        Button(name) {
                            controller.mutateConfiguration { config in
                                if selected {
                                    config.schedule.activeWeekdays.remove(weekday)
                                } else {
                                    config.schedule.activeWeekdays.insert(weekday)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(selected ? .accentColor : .secondary)
                        .background(selected ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                }
                if controller.configuration.schedule.startMinutes > controller.configuration.schedule.endMinutes {
                    Text("跨午夜规则：结束时间属于次日。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Stepper(
                    "提前保护：\(controller.configuration.schedule.protectionLeadMinutes) 分钟",
                    value: Binding(
                        get: { controller.configuration.schedule.protectionLeadMinutes },
                        set: { value in controller.mutateConfiguration { $0.schedule.protectionLeadMinutes = value } }
                    ),
                    in: 0...120,
                    step: 5
                )
                Text("保护期内，Finder、终端、活动监视器和系统设置等高风险工具会显示遮罩；普通工作应用不受影响。设为 0 可关闭。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("每日额度") {
                Toggle(
                    "限制指定应用",
                    isOn: Binding(
                        get: { controller.configuration.limit.isEnabled },
                        set: { value in controller.mutateConfiguration { $0.limit.isEnabled = value } }
                    )
                )
                Stepper(
                    "每天最多使用 \(controller.configuration.limit.dailyMinutes) 分钟",
                    value: Binding(
                        get: { controller.configuration.limit.dailyMinutes },
                        set: { value in controller.mutateConfiguration { $0.limit.dailyMinutes = value } }
                    ),
                    in: 5...720,
                    step: 5
                )
                Text("在“应用”页选择受额度限制的应用。额度按本机活跃使用时间累计。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("连续使用与休息") {
                Toggle(
                    "限制连续使用",
                    isOn: Binding(
                        get: { controller.configuration.cycle.isEnabled },
                        set: { value in controller.mutateConfiguration { $0.cycle.isEnabled = value } }
                    )
                )
                Stepper(
                    "连续使用 \(controller.configuration.cycle.useMinutes) 分钟",
                    value: Binding(
                        get: { controller.configuration.cycle.useMinutes },
                        set: { value in controller.mutateConfiguration { $0.cycle.useMinutes = value } }
                    ),
                    in: 5...120,
                    step: 5
                )
                Stepper(
                    "强制休息 \(controller.configuration.cycle.restMinutes) 分钟",
                    value: Binding(
                        get: { controller.configuration.cycle.restMinutes },
                        set: { value in controller.mutateConfiguration { $0.cycle.restMinutes = value } }
                    ),
                    in: 1...60,
                    step: 1
                )
                Text("连续使用规则作用于“计入每日额度的应用”。离开这些应用会中断连续计时。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("运行") {
                Toggle(
                    "登录后自动启动",
                    isOn: Binding(
                        get: { controller.configuration.launchAtLogin },
                        set: { value in controller.setLaunchAtLogin(value) }
                    )
                )
                Toggle(
                    "规则生效时自动恢复后台",
                    isOn: Binding(
                        get: { controller.configuration.backgroundRecovery },
                        set: { value in controller.setBackgroundRecovery(value) }
                    )
                )
                Text("启用后，规则仍生效而主程序被关闭时，系统后台助手会重新启动守屏。可在同一位置关闭。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(
                    "在 Finder 中隐藏应用",
                    isOn: Binding(
                        get: { controller.configuration.hideApplicationInFinder },
                        set: { controller.setHideApplicationInFinder($0) }
                    )
                )
                Text("隐藏后在 Finder 的“应用程序”中普通浏览不会看到守屏，但菜单栏入口和登录自动启动仍然有效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("登录启动：\(controller.loginServiceStatusText)")
                        Text("后台恢复：\(controller.backgroundServiceStatusText)")
                        HStack {
                            Button("打开登录项设置") { controller.openLoginItemsSettings() }
                            Spacer()
                            Text("后台助手每 5 秒检查一次当前规则。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(6)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .sheet(isPresented: $showingPasswordSetup) {
            PasswordSetupView()
                .environmentObject(controller)
        }
        .confirmationDialog(
            "移除退出密码？",
            isPresented: $confirmingPasswordRemoval
        ) {
            Button("移除密码", role: .destructive) { controller.removeExitPassword() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("移除后，暂停和跳过入口会被禁用，直到重新设置密码。")
        }
    }

    private static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
}

private struct ScheduleTimePicker: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker(
                title,
                selection: Binding(
                    get: { Self.date(from: minutes) },
                    set: { minutes = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private static func date(from minutes: Int) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }
}

private struct ApplicationListSection: View {
    let title: String
    let caption: String
    let applications: [AppDescriptor]
    let addTitle: String
    let onAdd: () -> Void
    let onRemove: (AppDescriptor) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(addTitle, action: onAdd)
                }

                if applications.isEmpty {
                    Text("尚未添加应用")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                } else {
                    ForEach(applications) { application in
                        HStack(spacing: 10) {
                            Image(nsImage: appIcon(for: application))
                                .resizable()
                                .frame(width: 26, height: 26)
                            Text(application.displayName)
                            Spacer()
                            Button(role: .destructive) {
                                onRemove(application)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                        if application.id != applications.last?.id { Divider() }
                    }
                }
            }
            .padding(8)
        }
    }

    private func appIcon(for application: AppDescriptor) -> NSImage {
        guard let path = application.bundlePath else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: application.displayName)
                ?? NSImage(size: NSSize(width: 32, height: 32))
        }
        return NSWorkspace.shared.icon(forFile: path)
    }
}

private struct ApplicationsView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ApplicationListSection(
                    title: "专注时可用的应用",
                    caption: "专注或定时限制生效时，未列出的第三方应用会被遮挡。",
                    applications: controller.configuration.allowedApplications,
                    addTitle: "添加允许应用",
                    onAdd: { controller.chooseAllowedApplications() },
                    onRemove: { controller.removeAllowedApplication($0) }
                )

                ApplicationListSection(
                    title: "计入每日额度的应用",
                    caption: "达到额度后，只遮挡这里列出的应用，其他应用仍可正常使用。",
                    applications: controller.configuration.limitedApplications,
                    addTitle: "添加受限应用",
                    onAdd: { controller.chooseLimitedApplications() },
                    onRemove: { controller.removeLimitedApplication($0) }
                )
            }
            .padding(24)
            .frame(maxWidth: 720)
        }
    }
}

private struct UsageView: View {
    @EnvironmentObject private var controller: AppController
    @State private var confirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日应用使用")
                        .font(.title2.weight(.semibold))
                    Text("只记录前台应用与活跃时间，不保存窗口标题或屏幕内容。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("清空今日记录", role: .destructive) { confirmingClear = true }
            }

            GroupBox {
                if controller.usage.sortedEntries.isEmpty {
                    ContentUnavailableView(
                        "还没有记录",
                        systemImage: "chart.bar",
                        description: Text("正常使用应用后，这里会出现今天的活跃时长。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    VStack(spacing: 0) {
                        ForEach(controller.usage.sortedEntries) { entry in
                            HStack(spacing: 12) {
                                Text(entry.displayName)
                                Spacer()
                                Text(AppController.durationText(seconds: Int(entry.activeSeconds.rounded())))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            if entry.id != controller.usage.sortedEntries.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            Spacer()
        }
        .padding(24)
        .confirmationDialog("清空今天的应用使用记录？", isPresented: $confirmingClear) {
            Button("清空今日记录", role: .destructive) { controller.clearUsage() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后，今天的额度也会按照 0 分钟重新计算。")
        }
    }
}

private struct PrivacyView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("权限与隐私")
                        .font(.title2.weight(.semibold))
                    Text("标准遮挡模式无需读取输入。只有你开启强制键盘锁定时，守屏才会请求辅助功能与输入监控权限。")
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: controller.accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield")
                            .font(.system(size: 34))
                            .foregroundStyle(controller.accessibilityTrusted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(controller.accessibilityTrusted ? "辅助功能已授权" : "辅助功能尚未授权")
                                .font(.headline)
                            Text("键盘拦截依赖系统辅助功能权限。授权后请重新测试；撤回权限时，守屏会自动降级为标准遮挡。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("刷新状态") { controller.refreshPermissions() }
                    }
                    .padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: controller.accessibilityTrusted && controller.inputMonitoringTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(controller.accessibilityTrusted && controller.inputMonitoringTrusted ? .green : .red)
                            Text(controller.accessibilityTrusted && controller.inputMonitoringTrusted ? "两项权限已生效" : "权限尚未成功生效")
                                .font(.headline)
                            Spacer()
                            Button("实际测试") { controller.testInputAccess() }
                        }
                        if let message = controller.permissionTestMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("“系统设置里已勾选”不等同于当前构建已获得权限。更改签名后，macOS 可能要求重新授权。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: controller.inputMonitoringTrusted ? "checkmark.shield.fill" : "exclamationmark.shield")
                            .font(.system(size: 34))
                            .foregroundStyle(controller.inputMonitoringTrusted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(controller.inputMonitoringTrusted ? "输入监控已授权" : "输入监控尚未授权")
                                .font(.headline)
                            Text("输入监控只用于判断和拦截退出专注屏所需的键盘事件，不会保存按键内容。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("请求输入监控权限") { controller.requestInputMonitoringPermission() }
                    }
                    .padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("权限操作", systemImage: "gear")
                            .font(.headline)
                        HStack {
                            Button("请求辅助功能权限") { controller.requestAccessibilityPermission() }
                            Button("打开系统设置") { controller.openAccessibilitySettings() }
                        }
                    }
                    .padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("本地数据", systemImage: "internaldrive")
                            .font(.headline)
                        Text("规则、应用列表和今日使用时长保存在 Application Support/Shouping。应用不会上传窗口标题、网页正文、屏幕画面或按键内容。")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

struct ShieldView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.08, blue: 0.13), Color(red: 0.10, green: 0.12, blue: 0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 520, height: 520)
                    .blur(radius: 40)
                    .offset(x: 320, y: -220)

                VStack(spacing: 24) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(.teal)

                    VStack(spacing: 8) {
                        Text(controller.isPreviewing ? "专注屏预览" : (controller.activeRestriction?.reason.title ?? "专注"))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text(controller.remainingText)
                            .font(.system(size: 58, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText())
                        Text(controller.activeRestriction?.reason.advice ?? "这是专注屏预览，10 秒后自动恢复。")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    if !controller.configuration.allowedApplications.isEmpty {
                        VStack(spacing: 10) {
                            Text("允许使用")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(controller.configuration.allowedApplications) { application in
                                        Button {
                                            controller.openApplication(application)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(nsImage: appIcon(for: application))
                                                    .resizable()
                                                    .frame(width: 24, height: 24)
                                                Text(application.displayName)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 12)
                                            .frame(height: 42)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .frame(maxWidth: 660)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: 660)
                        }
                    }

                    HStack(spacing: 14) {
                        if controller.canPauseCurrentRestriction {
                            Button("暂停…") { controller.requestPauseAuthorization() }
                                .buttonStyle(.bordered)
                        }
                        if controller.canSkipCurrentRestriction {
                            Button(skipButtonTitle) { controller.requestSkipAuthorization() }
                                .buttonStyle(.bordered)
                        }
                    }

                    if controller.configuration.focus.strength == .strict,
                       controller.configuration.focus.enforceKeyboardLock,
                       controller.configuration.focus.controls.allowPause,
                       controller.hasExitPassword {
                        VStack(spacing: 5) {
                            Text(controller.inputGateRunning ? "键盘拦截已开启" : "键盘拦截不可用，当前仍受全屏遮挡保护")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(controller.inputGateRunning ? Color.teal.opacity(0.8) : Color.orange.opacity(0.85))
                            Text("紧急快捷键：Control + Command + U")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.42))
                        }
                    }
                }
                .padding(40)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func appIcon(for application: AppDescriptor) -> NSImage {
        guard let path = application.bundlePath else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: application.displayName)
                ?? NSImage(size: NSSize(width: 32, height: 32))
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private var skipButtonTitle: String {
        if controller.isPreviewing { return "结束预览" }
        if controller.activeRestriction?.reason == .quickFocus { return "结束本次专注" }
        return "跳过当前限制"
    }
}

private struct PasswordSetupView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置退出密码")
                .font(.title2.weight(.bold))
            Text("暂停或跳过专注前必须输入此密码。密码只保存在 macOS Keychain，无法找回。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("新密码（至少 4 位）", text: $password)
                .textFieldStyle(.roundedBorder)
            SecureField("再次输入密码", text: $confirmation)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    guard password == confirmation else {
                        error = "两次输入的密码不一致。"
                        return
                    }
                    if controller.setExitPassword(password) {
                        dismiss()
                    } else {
                        error = controller.lastError
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.count < 4 || confirmation.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 430)
    }
}
