import AppKit
import ShoupingCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("今天", systemImage: "sun.max") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
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
                            Button("暂停") { controller.requestPauseAuthorization() }
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

private enum SettingsSection: String, CaseIterable, Identifiable {
    case focus
    case controls
    case clock
    case schedules
    case dailyLimit
    case cycle
    case runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "专注强度"
        case .controls: return "暂停与跳过"
        case .clock: return "时钟屏保"
        case .schedules: return "定时专注"
        case .dailyLimit: return "每日额度"
        case .cycle: return "连续使用与休息"
        case .runtime: return "运行"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "timer"
        case .controls: return "key.fill"
        case .clock: return "clock"
        case .schedules: return "calendar"
        case .dailyLimit: return "gauge.with.dots.needle.50percent"
        case .cycle: return "arrow.triangle.2.circlepath"
        case .runtime: return "power"
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var controller: AppController
    @State private var showingPasswordSetup = false
    @State private var showingPasswordRemoval = false
    @State private var selectedSection: SettingsSection = .focus

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                SettingsSidebar(selection: selectedSection) { section in
                    selectedSection = section
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(section.id, anchor: .top)
                    }
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SettingsCard(.focus) {
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
                        .id(SettingsSection.focus.id)

                        SettingsCard(.controls) {
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
                            showingPasswordRemoval = true
                        }
                    }
                }
                Text("密码保存在 macOS Keychain。未设置密码时，暂停和跳过入口不会出现。密码无法找回；移除密码前需要验证当前密码。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                        }
                        .id(SettingsSection.controls.id)

                        SettingsCard(.clock) {
                Toggle(
                    "显示天气",
                    isOn: Binding(
                        get: { controller.configuration.appearance.weatherEnabled },
                        set: { enabled in
                            controller.mutateConfiguration { $0.appearance.weatherEnabled = enabled }
                            if enabled { controller.refreshWeather() }
                        }
                    )
                )

                if controller.configuration.appearance.weatherEnabled {
                    HStack {
                        TextField(
                            "城市，例如：上海",
                            text: Binding(
                                get: { controller.configuration.appearance.weatherCity },
                                set: { city in controller.mutateConfiguration { $0.appearance.weatherCity = city } }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        Button("获取天气") { controller.refreshWeather() }
                    }
                    Text(controller.weatherStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("天气由 Open-Meteo 提供。启用后，应用会把填写的城市和网络请求发送到该服务，不读取或上传本机定位。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                        }
                        .id(SettingsSection.clock.id)

                        SettingsCard(.schedules) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("中国大陆工作日历")
                            .font(.headline)
                        Text(controller.holidayStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("刷新") { controller.refreshHolidayCalendar(force: true) }
                }
                Text("“工作日”包含法定补班日，“非工作日”包含周末和法定假日。数据按年度自动获取；无网络或新年度尚未公布时回退为周一至周五/周六周日。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(controller.configuration.schedules) { rule in
                    ScheduleRuleEditor(rule: rule)
                }

                if controller.configuration.schedules.isEmpty {
                    Text("尚未添加定时方案")
                        .foregroundStyle(.secondary)
                }

                Button("＋ 添加时间方案") { controller.addScheduleRule() }
                        }
                        .id(SettingsSection.schedules.id)

                        SettingsCard(.dailyLimit) {
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
                        .id(SettingsSection.dailyLimit.id)

                        SettingsCard(.cycle) {
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
                        .id(SettingsSection.cycle.id)

                        SettingsCard(.runtime) {
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
                        .id(SettingsSection.runtime.id)
                    }
                    .padding(24)
                    .frame(maxWidth: 780, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .sheet(isPresented: $showingPasswordSetup) {
            PasswordSetupView()
                .environmentObject(controller)
        }
        .sheet(isPresented: $showingPasswordRemoval) {
            PasswordRemovalView()
                .environmentObject(controller)
        }
    }
}

private struct SettingsSidebar: View {
    let selection: SettingsSection
    let onSelect: (SettingsSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("设置")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 10)
            Text("点击标题跳转")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            ForEach(SettingsSection.allCases) { section in
                let isSelected = section == selection
                Button {
                    onSelect(section)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: section.icon)
                            .frame(width: 18)
                        Text(section.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(
                        isSelected ? Color.accentColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(12)
        .frame(minWidth: 160, idealWidth: 176, maxWidth: 210)
        .background(.regularMaterial)
    }
}

private struct SettingsCard<Content: View>: View {
    let section: SettingsSection
    let content: Content

    init(_ section: SettingsSection, @ViewBuilder content: () -> Content) {
        self.section = section
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(section.title, systemImage: section.icon)
                .font(.title3.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ScheduleRuleEditor: View {
    @EnvironmentObject private var controller: AppController
    let rule: ScheduleRule

    private static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("方案名称", text: binding(\.name))
                        .textFieldStyle(.roundedBorder)
                    Toggle("启用", isOn: binding(\.isEnabled))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    Button(role: .destructive) {
                        controller.removeScheduleRule(id: rule.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("删除这个时间方案")
                }

                HStack(spacing: 18) {
                    ScheduleTimePicker(title: "开始", minutes: binding(\.startMinutes))
                    ScheduleTimePicker(title: "结束", minutes: binding(\.endMinutes))
                }

                Picker("日期类型", selection: binding(\.dayMode)) {
                    ForEach(ScheduleDayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if currentRule.dayMode == .customWeekdays {
                    HStack(spacing: 8) {
                        ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { index, name in
                            let weekday = index + 1
                            let selected = currentRule.customWeekdays.contains(weekday)
                            Button(name) {
                                controller.updateScheduleRule(id: rule.id) { target in
                                    if selected {
                                        target.customWeekdays.remove(weekday)
                                    } else {
                                        target.customWeekdays.insert(weekday)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(selected ? .accentColor : .secondary)
                            .background(selected ? Color.accentColor.opacity(0.12) : Color.clear)
                        }
                    }
                }

                Text(dayModeExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(
                    "提前保护：\(currentRule.protectionLeadMinutes) 分钟",
                    value: binding(\.protectionLeadMinutes),
                    in: 0...120,
                    step: 5
                )

                if currentRule.startMinutes > currentRule.endMinutes {
                    Text("跨午夜规则：结束时间属于次日。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
        }
    }

    private var currentRule: ScheduleRule {
        controller.configuration.schedules.first { $0.id == rule.id } ?? rule
    }

    private var dayModeExplanation: String {
        switch currentRule.dayMode {
        case .customWeekdays:
            return "只在你选中的星期生效。"
        case .workdays:
            return "按中国大陆工作日生效，包含周末补班，排除法定假日。"
        case .nonWorkdays:
            return "按中国大陆非工作日生效，包含周末和法定假日，排除补班日。"
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ScheduleRule, Value>) -> Binding<Value> {
        Binding(
            get: { currentRule[keyPath: keyPath] },
            set: { value in
                controller.updateScheduleRule(id: rule.id) { target in
                    target[keyPath: keyPath] = value
                }
            }
        )
    }
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
                        Text("设置、应用列表和今日使用时长保存在 Application Support/Shouping。应用不会上传窗口标题、网页正文、屏幕画面或按键内容。")
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
            clockContent
        }
    }

    private var clockContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer()

                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: 210, weight: .thin, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)

                Text(Date(), format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.55))

                if controller.configuration.appearance.weatherEnabled {
                    if let weather = controller.weather {
                        HStack(spacing: 8) {
                            Image(systemName: weather.symbolName)
                            Text("\(weather.temperatureCelsius)°  \(weather.condition)")
                            Text(weather.city)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.78))
                    } else {
                        Text(controller.weatherStatusText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }

                Spacer()

                if !controller.configuration.allowedApplications.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(controller.configuration.allowedApplications.prefix(8)) { application in
                            Button {
                                controller.openApplication(application)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(nsImage: appIcon(for: application))
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text(application.displayName)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if controller.canPauseCurrentRestriction {
                        Button("暂停") { controller.requestPauseAuthorization() }
                    }
                    if controller.canSkipCurrentRestriction {
                        Button(skipButtonTitle) { controller.requestSkipAuthorization() }
                    }
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 42)
            }
            .padding(.horizontal, 40)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @State private var generatedPassword: String?
    @State private var generatedAt: Date?
    @State private var didCopyForAdoption = false
    @State private var adoptionStep = 0
    @State private var showingAdoptionConfirmation = false
    @State private var adoptionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(controller.hasExitPassword ? "修改退出密码" : "设置退出密码")
                .font(.title2.weight(.bold))
            Text("暂停或跳过专注前必须输入此密码。密码只保存在 macOS Keychain，无法找回；保存后必须验证当前密码才能移除。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RevealablePasswordField(text: $password, prompt: "新密码（至少 4 位）")
                .onChange(of: password) { _, _ in passwordDidChange() }
            RevealablePasswordField(text: $confirmation, prompt: "再次输入密码")
                .onChange(of: confirmation) { _, _ in resetCopyStatus() }

            if let generatedAt, generatedPassword == password {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("本次生成的随机密码", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(generatedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(password)
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button("随机生成密码", systemImage: "dice.fill") {
                    let generated = ExitPasswordGenerator.make()
                    let now = Date()
                    generatedPassword = generated
                    generatedAt = now
                    password = generated
                    confirmation = generated
                    error = nil
                    adoptionMessage = nil
                    didCopyForAdoption = false
                }
                Button("复制密码和说明", systemImage: "doc.on.doc") {
                    copyForAdoption()
                }
                .disabled(password.count < 4)

                Spacer()
                Button("此次采用密码", systemImage: "checkmark.shield") {
                    beginAdoption()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!didCopyForAdoption)
            }

            if didCopyForAdoption {
                Label("已复制密码和生成时间。请发送给保密人后再采用。", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let adoptionMessage {
                Label(adoptionMessage, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 540)
        .alert(adoptionConfirmationTitle, isPresented: $showingAdoptionConfirmation) {
            Button("否", role: .cancel) { failAdoption() }
            Button(adoptionAffirmativeButtonTitle) { advanceAdoption() }
        } message: {
            Text(adoptionConfirmationMessage)
        }
    }

    private var adoptionConfirmationTitle: String {
        switch adoptionStep {
        case 2: return "再次确认是否已发送（2/3）"
        case 3: return "最终确认采用密码（3/3）"
        default: return "确认发送密码（1/3）"
        }
    }

    private var adoptionConfirmationMessage: String {
        switch adoptionStep {
        case 2:
            return "再次确认：是否已经将这段密码发送给保密人？"
        case 3:
            return "最后一次确认：是否已经将密码发送给保密人，并现在采用、保存这个密码？"
        default:
            return "是否已经将这段密码发送给保密人？"
        }
    }

    private var adoptionAffirmativeButtonTitle: String {
        adoptionStep == 3 ? "是，采用密码" : "是，已经发送"
    }

    private func passwordDidChange() {
        if generatedPassword != password {
            generatedPassword = nil
            generatedAt = nil
        }
        resetCopyStatus()
    }

    private func resetCopyStatus() {
        didCopyForAdoption = false
        adoptionStep = 0
        showingAdoptionConfirmation = false
        adoptionMessage = nil
    }

    private func copyForAdoption() {
        guard password.count >= 4 else { return }
        let now = generatedAt ?? Date()
        let sharingText = ExitPasswordGenerator.sharingText(for: password, generatedAt: now)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(sharingText, forType: .string) else {
            didCopyForAdoption = false
            adoptionMessage = "复制失败，密码尚未准备采用。"
            return
        }
        didCopyForAdoption = true
        adoptionMessage = nil
        error = nil
    }

    private func beginAdoption() {
        guard didCopyForAdoption else {
            adoptionMessage = "请先复制密码和说明，再采用密码。"
            return
        }
        guard password == confirmation else {
            error = "两次输入的密码不一致。"
            return
        }
        adoptionStep = 1
        showingAdoptionConfirmation = true
    }

    private func advanceAdoption() {
        showingAdoptionConfirmation = false
        if adoptionStep < 3 {
            adoptionStep += 1
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                showingAdoptionConfirmation = true
            }
            return
        }

        if controller.setExitPassword(password) {
            dismiss()
        } else {
            error = controller.lastError
            adoptionMessage = "采用失败，密码没有保存。"
            adoptionStep = 0
        }
    }

    private func failAdoption() {
        showingAdoptionConfirmation = false
        adoptionStep = 0
        adoptionMessage = "采用失败：尚未确认已将密码发送给保密人。密码没有保存。"
    }
}

private struct PasswordRemovalView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("移除退出密码")
                .font(.title2.weight(.bold))
            Text("请先输入当前退出密码。验证通过后才会移除密码，并禁用暂停与跳过入口。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RevealablePasswordField(text: $currentPassword, prompt: "当前退出密码", onSubmit: removePassword)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("验证并移除", role: .destructive, action: removePassword)
                    .buttonStyle(.borderedProminent)
                    .disabled(currentPassword.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 430)
    }

    private func removePassword() {
        if let message = controller.removeExitPassword(currentPassword: currentPassword) {
            error = message
        } else {
            dismiss()
        }
    }
}
