import Foundation

public struct RuleEngine: Sendable {
    public static let protectedSystemManagementApplications: Set<String> = [
        "com.apple.finder",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.apple.ActivityMonitor",
        "com.apple.systempreferences",
        "com.apple.ScriptEditor2",
        "com.apple.shortcuts",
    ]

    public init() {}

    public func activeRestriction(
        configuration: AppConfiguration,
        usage: DailyUsage,
        now: Date,
        calendar: Calendar = .current,
        holidayCalendar: ChineseHolidayCalendar = ChineseHolidayCalendar(),
        honorTemporaryUnlock: Bool = true
    ) -> ActiveRestriction? {
        if let skippedEnd = configuration.skippedRestrictionEndUnixTime,
           Date(timeIntervalSince1970: skippedEnd) > now {
            return nil
        }

        if honorTemporaryUnlock,
           let unlockEnd = configuration.temporaryUnlockEndUnixTime,
           Date(timeIntervalSince1970: unlockEnd) > now {
            return nil
        }

        if let focusEnd = configuration.focusEndUnixTime,
           Date(timeIntervalSince1970: focusEnd) > now {
            return ActiveRestriction(
                reason: .quickFocus,
                endDate: Date(timeIntervalSince1970: focusEnd),
                blockedBundleIdentifiers: [],
                allowsOnlySelectedApplications: true
            )
        }

        let rules = effectiveScheduleRules(configuration)
        let activeEnds = rules.compactMap { rule -> Date? in
            guard scheduleIsActive(rule, now: now, calendar: calendar, holidayCalendar: holidayCalendar) else {
                return nil
            }
            return scheduleEndDate(rule, now: now, calendar: calendar)
        }
        if let endDate = activeEnds.max() {
            return ActiveRestriction(
                reason: .schedule,
                endDate: endDate,
                blockedBundleIdentifiers: [],
                allowsOnlySelectedApplications: true
            )
        }

        if configuration.limit.isEnabled {
            let limitSeconds = TimeInterval(max(configuration.limit.dailyMinutes, 0) * 60)
            let usedSeconds = usage.seconds(for: configuration.limitedBundleIdentifiers)
            if limitSeconds > 0,
               usedSeconds >= limitSeconds,
               !configuration.limitedBundleIdentifiers.isEmpty {
                return ActiveRestriction(
                    reason: .dailyLimit,
                    endDate: nil,
                    blockedBundleIdentifiers: configuration.limitedBundleIdentifiers,
                    allowsOnlySelectedApplications: false
                )
            }
        }

        if let preLockStart = nextPreLockStart(
            rules: rules,
            now: now,
            calendar: calendar,
            holidayCalendar: holidayCalendar
        ) {
            return ActiveRestriction(
                reason: .preLockGuard,
                endDate: preLockStart,
                blockedBundleIdentifiers: Self.protectedSystemManagementApplications,
                allowsOnlySelectedApplications: false
            )
        }

        return nil
    }

    public func effectiveScheduleRules(_ configuration: AppConfiguration) -> [ScheduleRule] {
        configuration.schedules
    }

    public func scheduleIsActive(
        _ rule: ScheduleRule,
        now: Date,
        calendar: Calendar = .current,
        holidayCalendar: ChineseHolidayCalendar = ChineseHolidayCalendar()
    ) -> Bool {
        guard rule.isEnabled, rule.startMinutes != rule.endMinutes else { return false }

        let minute = minuteOfDay(now, calendar: calendar)
        if rule.startMinutes < rule.endMinutes {
            return matchesDay(rule, date: now, calendar: calendar, holidayCalendar: holidayCalendar)
                && minute >= rule.startMinutes
                && minute < rule.endMinutes
        }

        if minute >= rule.startMinutes {
            return matchesDay(rule, date: now, calendar: calendar, holidayCalendar: holidayCalendar)
        }
        if minute < rule.endMinutes,
           let previousDay = calendar.date(byAdding: .day, value: -1, to: now) {
            return matchesDay(rule, date: previousDay, calendar: calendar, holidayCalendar: holidayCalendar)
        }
        return false
    }

    public func scheduleIsActive(
        _ schedule: ScheduleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        scheduleIsActive(schedule.migratingToRule(), now: now, calendar: calendar)
    }

    public func scheduleEndDate(
        _ rule: ScheduleRule,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard rule.startMinutes != rule.endMinutes else { return nil }
        let minute = minuteOfDay(now, calendar: calendar)
        let midnight = calendar.startOfDay(for: now)
        guard let todayEnd = calendar.date(byAdding: .minute, value: rule.endMinutes, to: midnight) else {
            return nil
        }

        if rule.startMinutes < rule.endMinutes || minute < rule.endMinutes {
            return todayEnd > now ? todayEnd : calendar.date(byAdding: .day, value: 1, to: todayEnd)
        }
        return calendar.date(byAdding: .day, value: 1, to: todayEnd)
    }

    public func scheduleEndDate(
        _ schedule: ScheduleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        scheduleEndDate(schedule.migratingToRule(), now: now, calendar: calendar)
    }

    public func scheduleStartDate(
        _ rule: ScheduleRule,
        now: Date,
        calendar: Calendar = .current,
        holidayCalendar: ChineseHolidayCalendar = ChineseHolidayCalendar()
    ) -> Date? {
        guard rule.isEnabled else { return nil }
        for dayOffset in 0...14 {
            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: calendar.startOfDay(for: now)
            ), matchesDay(rule, date: day, calendar: calendar, holidayCalendar: holidayCalendar),
                let start = calendar.date(byAdding: .minute, value: rule.startMinutes, to: day),
                start > now else {
                continue
            }
            return start
        }
        return nil
    }

    public func scheduleStartDate(
        _ schedule: ScheduleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        scheduleStartDate(schedule.migratingToRule(), now: now, calendar: calendar)
    }

    public func schedulePreLockIsActive(
        _ schedule: ScheduleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard schedule.isEnabled,
              schedule.protectionLeadMinutes > 0,
              !scheduleIsActive(schedule, now: now, calendar: calendar),
              let start = scheduleStartDate(schedule, now: now, calendar: calendar) else {
            return false
        }
        let remaining = start.timeIntervalSince(now)
        return remaining > 0 && remaining <= TimeInterval(schedule.protectionLeadMinutes * 60)
    }

    public func shouldBlockApplication(
        bundleIdentifier: String,
        restriction: ActiveRestriction,
        allowedBundleIdentifiers: Set<String>
    ) -> Bool {
        if restriction.allowsOnlySelectedApplications {
            return !allowedBundleIdentifiers.contains(bundleIdentifier)
        }
        return restriction.blockedBundleIdentifiers.contains(bundleIdentifier)
    }

    private func nextPreLockStart(
        rules: [ScheduleRule],
        now: Date,
        calendar: Calendar,
        holidayCalendar: ChineseHolidayCalendar
    ) -> Date? {
        var candidate: Date?
        for rule in rules where rule.isEnabled && rule.protectionLeadMinutes > 0 {
            guard let start = scheduleStartDate(
                rule,
                now: now,
                calendar: calendar,
                holidayCalendar: holidayCalendar
            ) else {
                continue
            }
            let remaining = start.timeIntervalSince(now)
            guard remaining > 0,
                  remaining <= TimeInterval(rule.protectionLeadMinutes * 60) else {
                continue
            }
            if candidate == nil || start < candidate! {
                candidate = start
            }
        }
        return candidate
    }

    private func matchesDay(
        _ rule: ScheduleRule,
        date: Date,
        calendar: Calendar,
        holidayCalendar: ChineseHolidayCalendar
    ) -> Bool {
        switch rule.dayMode {
        case .customWeekdays:
            return rule.customWeekdays.contains(calendar.component(.weekday, from: date))
        case .workdays:
            return holidayCalendar.isWorkday(date, calendar: calendar)
        case .nonWorkdays:
            return holidayCalendar.isNonWorkday(date, calendar: calendar)
        }
    }

    private func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
