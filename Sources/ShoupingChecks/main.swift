import Foundation
import ShoupingCore

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

let engine = RuleEngine()

try expect(
    engine.scheduleIsActive(
        ScheduleSettings(
            isEnabled: true,
            activeWeekdays: [2],
            startMinutes: 9 * 60,
            endMinutes: 11 * 60
        ),
        now: date(2026, 11, 23, 10),
        calendar: calendar
    ),
    "普通工作日日程未正确生效"
)

try expect(
    engine.scheduleIsActive(
        ScheduleSettings(
            isEnabled: true,
            activeWeekdays: [2],
            startMinutes: 23 * 60,
            endMinutes: 7 * 60
        ),
        now: date(2026, 11, 24, 6),
        calendar: calendar
    ),
    "跨午夜日程未正确延续到次日"
)

let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
var focusConfiguration = AppConfiguration()
focusConfiguration.focusEndUnixTime = fixedNow.addingTimeInterval(1_800).timeIntervalSince1970
focusConfiguration.temporaryUnlockEndUnixTime = fixedNow.addingTimeInterval(300).timeIntervalSince1970
try expect(
    engine.activeRestriction(
        configuration: focusConfiguration,
        usage: DailyUsage(dayKey: "2027-01-15"),
        now: fixedNow,
        calendar: calendar
    ) == nil,
    "临时解锁未覆盖正在生效的规则"
)

var limitConfiguration = AppConfiguration()
limitConfiguration.limit = LimitSettings(isEnabled: true, dailyMinutes: 30)
limitConfiguration.limitedApplications = [
    AppDescriptor(bundleIdentifier: "com.example.video", displayName: "Video")
]
var usage = DailyUsage(dayKey: "2026-11-20")
usage.applications["com.example.video"] = UsageEntry(
    bundleIdentifier: "com.example.video",
    displayName: "Video",
    activeSeconds: 1_800
)
let restriction = engine.activeRestriction(
    configuration: limitConfiguration,
    usage: usage,
    now: fixedNow,
    calendar: calendar
)
try expect(restriction?.reason == .dailyLimit, "达到每日额度后未触发限制")
try expect(
    engine.shouldBlockApplication(
        bundleIdentifier: "com.example.video",
        restriction: restriction!,
        allowedBundleIdentifiers: []
    ),
    "额度用完但没有拦截目标应用"
)
try expect(
    !engine.shouldBlockApplication(
        bundleIdentifier: "com.example.editor",
        restriction: restriction!,
        allowedBundleIdentifiers: []
    ),
    "额度模式错误拦截了非目标应用"
)

let temporaryDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("shouping-checks-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
let usageURL = temporaryDirectory.appendingPathComponent("usage.json")
let store = UsageStore(fileURL: usageURL, calendar: calendar)
let sample = AppDescriptor(bundleIdentifier: "com.example.browser", displayName: "Browser")
store.add(seconds: 120, to: sample, now: date(2026, 11, 20, 12))
store.persist()
let reloaded = UsageStore(fileURL: usageURL, calendar: calendar)
try expect(
    reloaded.daily.applications[sample.bundleIdentifier]?.activeSeconds == 120,
    "应用使用记录未正确持久化"
)
try expect(
    reloaded.rollDayIfNeeded(now: date(2026, 11, 21, 1)),
    "跨日时未生成新的一天"
)
try expect(reloaded.daily.applications.isEmpty, "跨日重置后旧记录仍然存在")

var cycle = CycleTracker()
let cycleStart = date(2026, 11, 20, 12)
cycle.update(
    settings: CycleSettings(isEnabled: true, useMinutes: 30, restMinutes: 5),
    isLimitedUse: true,
    isUserActive: true,
    elapsed: 1_800,
    now: cycleStart
)
try expect(cycle.restEnd != nil, "连续使用达到阈值后没有开始休息")
let restEnd = cycle.restEnd!
cycle.update(
    settings: CycleSettings(isEnabled: true, useMinutes: 30, restMinutes: 5),
    isLimitedUse: true,
    isUserActive: true,
    elapsed: 1,
    now: restEnd.addingTimeInterval(1)
)
try expect(cycle.restEnd == nil, "休息结束后没有清除休息状态")
try expect(cycle.continuousSeconds == 0, "休息结束后没有重置连续使用计时")

print("ShoupingChecks: 11 checks passed")
