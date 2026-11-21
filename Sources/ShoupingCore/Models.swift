import Foundation

public enum LockReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case quickFocus
    case schedule
    case dailyLimit
    case cycleRest
    case preLockGuard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quickFocus: return "专注进行中"
        case .schedule: return "现在是用机限制时段"
        case .dailyLimit: return "今天的使用额度已用完"
        case .cycleRest: return "该休息一下了"
        case .preLockGuard: return "专注即将开始"
        }
    }

    public var advice: String {
        switch self {
        case .quickFocus: return "先把眼前这一件事做完。"
        case .schedule: return "现在休息一下，留些时间给真正重要的事情。"
        case .dailyLimit: return "今天的娱乐额度已经结束，明天再继续。"
        case .cycleRest: return "离开屏幕几分钟，让注意力恢复一下。"
        case .preLockGuard: return "现在不要卸载或修改守屏，马上进入专注时段。"
        }
    }
}

public enum InterventionStrength: String, Codable, CaseIterable, Identifiable, Sendable {
    case reminder
    case shield
    case strict

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .reminder: return "提醒"
        case .shield: return "遮挡"
        case .strict: return "强制"
        }
    }
}

public struct FocusControls: Codable, Equatable, Sendable {
    public var allowPause: Bool
    public var allowSkip: Bool

    public init(allowPause: Bool = true, allowSkip: Bool = true) {
        self.allowPause = allowPause
        self.allowSkip = allowSkip
    }
}

public struct AppDescriptor: Codable, Hashable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }
    public var bundleIdentifier: String
    public var displayName: String
    public var bundlePath: String?

    public init(bundleIdentifier: String, displayName: String, bundlePath: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.bundlePath = bundlePath
    }
}

public struct ScheduleSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var activeWeekdays: Set<Int>
    public var startMinutes: Int
    public var endMinutes: Int
    public var protectionLeadMinutes: Int

    public init(
        isEnabled: Bool = false,
        activeWeekdays: Set<Int> = Set(2...6),
        startMinutes: Int = 9 * 60,
        endMinutes: Int = 11 * 60 + 30,
        protectionLeadMinutes: Int = 15
    ) {
        self.isEnabled = isEnabled
        self.activeWeekdays = activeWeekdays
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.protectionLeadMinutes = protectionLeadMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case activeWeekdays
        case startMinutes
        case endMinutes
        case protectionLeadMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        activeWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .activeWeekdays) ?? Set(2...6)
        startMinutes = try container.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 9 * 60
        endMinutes = try container.decodeIfPresent(Int.self, forKey: .endMinutes) ?? 11 * 60 + 30
        protectionLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .protectionLeadMinutes) ?? 15
    }
}

public struct FocusSettings: Codable, Equatable, Sendable {
    public var strength: InterventionStrength
    public var enforceKeyboardLock: Bool
    public var defaultFocusMinutes: Int
    public var controls: FocusControls

    public init(
        strength: InterventionStrength = .shield,
        enforceKeyboardLock: Bool = false,
        defaultFocusMinutes: Int = 25,
        controls: FocusControls = FocusControls()
    ) {
        self.strength = strength
        self.enforceKeyboardLock = enforceKeyboardLock
        self.defaultFocusMinutes = defaultFocusMinutes
        self.controls = controls
    }

    private enum CodingKeys: String, CodingKey {
        case strength
        case enforceKeyboardLock
        case defaultFocusMinutes
        case controls
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strength = try container.decodeIfPresent(InterventionStrength.self, forKey: .strength) ?? .shield
        enforceKeyboardLock = try container.decodeIfPresent(Bool.self, forKey: .enforceKeyboardLock) ?? false
        defaultFocusMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultFocusMinutes) ?? 25
        controls = try container.decodeIfPresent(FocusControls.self, forKey: .controls) ?? FocusControls()
    }
}

public struct LimitSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var dailyMinutes: Int

    public init(isEnabled: Bool = false, dailyMinutes: Int = 60) {
        self.isEnabled = isEnabled
        self.dailyMinutes = dailyMinutes
    }
}

public struct CycleSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var useMinutes: Int
    public var restMinutes: Int

    public init(isEnabled: Bool = false, useMinutes: Int = 30, restMinutes: Int = 5) {
        self.isEnabled = isEnabled
        self.useMinutes = useMinutes
        self.restMinutes = restMinutes
    }
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var focus: FocusSettings
    public var schedule: ScheduleSettings
    public var limit: LimitSettings
    public var cycle: CycleSettings
    public var allowedApplications: [AppDescriptor]
    public var limitedApplications: [AppDescriptor]
    public var focusEndUnixTime: TimeInterval?
    public var temporaryUnlockEndUnixTime: TimeInterval?
    public var skippedRestrictionEndUnixTime: TimeInterval?
    public var launchAtLogin: Bool
    public var backgroundRecovery: Bool
    public var hideApplicationInFinder: Bool

    public init(
        focus: FocusSettings = FocusSettings(),
        schedule: ScheduleSettings = ScheduleSettings(),
        limit: LimitSettings = LimitSettings(),
        cycle: CycleSettings = CycleSettings(),
        allowedApplications: [AppDescriptor] = [],
        limitedApplications: [AppDescriptor] = [],
        focusEndUnixTime: TimeInterval? = nil,
        temporaryUnlockEndUnixTime: TimeInterval? = nil,
        skippedRestrictionEndUnixTime: TimeInterval? = nil,
        launchAtLogin: Bool = false,
        backgroundRecovery: Bool = false,
        hideApplicationInFinder: Bool = true
    ) {
        self.focus = focus
        self.schedule = schedule
        self.limit = limit
        self.cycle = cycle
        self.allowedApplications = allowedApplications
        self.limitedApplications = limitedApplications
        self.focusEndUnixTime = focusEndUnixTime
        self.temporaryUnlockEndUnixTime = temporaryUnlockEndUnixTime
        self.skippedRestrictionEndUnixTime = skippedRestrictionEndUnixTime
        self.launchAtLogin = launchAtLogin
        self.backgroundRecovery = backgroundRecovery
        self.hideApplicationInFinder = hideApplicationInFinder
    }

    public var allowedBundleIdentifiers: Set<String> {
        Set(allowedApplications.map(\.bundleIdentifier))
    }

    public var limitedBundleIdentifiers: Set<String> {
        Set(limitedApplications.map(\.bundleIdentifier))
    }

    private enum CodingKeys: String, CodingKey {
        case focus
        case schedule
        case limit
        case cycle
        case allowedApplications
        case limitedApplications
        case focusEndUnixTime
        case temporaryUnlockEndUnixTime
        case skippedRestrictionEndUnixTime
        case launchAtLogin
        case backgroundRecovery
        case hideApplicationInFinder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focus = try container.decodeIfPresent(FocusSettings.self, forKey: .focus) ?? FocusSettings()
        schedule = try container.decodeIfPresent(ScheduleSettings.self, forKey: .schedule) ?? ScheduleSettings()
        limit = try container.decodeIfPresent(LimitSettings.self, forKey: .limit) ?? LimitSettings()
        cycle = try container.decodeIfPresent(CycleSettings.self, forKey: .cycle) ?? CycleSettings()
        allowedApplications = try container.decodeIfPresent([AppDescriptor].self, forKey: .allowedApplications) ?? []
        limitedApplications = try container.decodeIfPresent([AppDescriptor].self, forKey: .limitedApplications) ?? []
        focusEndUnixTime = try container.decodeIfPresent(TimeInterval.self, forKey: .focusEndUnixTime)
        temporaryUnlockEndUnixTime = try container.decodeIfPresent(TimeInterval.self, forKey: .temporaryUnlockEndUnixTime)
        skippedRestrictionEndUnixTime = try container.decodeIfPresent(TimeInterval.self, forKey: .skippedRestrictionEndUnixTime)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        backgroundRecovery = try container.decodeIfPresent(Bool.self, forKey: .backgroundRecovery) ?? false
        hideApplicationInFinder = try container.decodeIfPresent(Bool.self, forKey: .hideApplicationInFinder) ?? true
    }
}

public struct UsageEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }
    public var bundleIdentifier: String
    public var displayName: String
    public var activeSeconds: TimeInterval

    public init(bundleIdentifier: String, displayName: String, activeSeconds: TimeInterval) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.activeSeconds = activeSeconds
    }
}

public struct DailyUsage: Codable, Equatable, Sendable {
    public var dayKey: String
    public var applications: [String: UsageEntry]

    public init(dayKey: String, applications: [String: UsageEntry] = [:]) {
        self.dayKey = dayKey
        self.applications = applications
    }

    public var sortedEntries: [UsageEntry] {
        applications.values.sorted { $0.activeSeconds > $1.activeSeconds }
    }

    public func seconds(for bundleIdentifiers: Set<String>) -> TimeInterval {
        bundleIdentifiers.reduce(0) { partial, bundleIdentifier in
            partial + (applications[bundleIdentifier]?.activeSeconds ?? 0)
        }
    }
}

public struct ActiveRestriction: Equatable, Sendable {
    public var reason: LockReason
    public var endDate: Date?
    public var blockedBundleIdentifiers: Set<String>
    public var allowsOnlySelectedApplications: Bool

    public init(
        reason: LockReason,
        endDate: Date?,
        blockedBundleIdentifiers: Set<String>,
        allowsOnlySelectedApplications: Bool
    ) {
        self.reason = reason
        self.endDate = endDate
        self.blockedBundleIdentifiers = blockedBundleIdentifiers
        self.allowsOnlySelectedApplications = allowsOnlySelectedApplications
    }
}
