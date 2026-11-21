import Foundation

public struct RuleEngine: Sendable {
    public init() {}

    public func activeRestriction(
        configuration: AppConfiguration,
        usage: DailyUsage,
        now: Date,
        calendar: Calendar = .current,
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

        if scheduleIsActive(configuration.schedule, now: now, calendar: calendar) {
            return ActiveRestriction(
                reason: .schedule,
                endDate: scheduleEndDate(configuration.schedule, now: now, calendar: calendar),
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

        return nil
    }

    public func scheduleIsActive(
        _ schedule: ScheduleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard schedule.isEnabled, !schedule.activeWeekdays.isEmpty else { return false }

        let start = schedule.startMinutes
        let end = schedule.endMinutes
        guard start != end else { return false }

        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        let weekday = components.weekday ?? calendar.component(.weekday, from: now)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if start < end {
            return schedule.activeWeekdays.contains(weekday) && minute >= start && minute < end
        }

        if minute >= start {
            return schedule.activeWeekdays.contains(weekday)
        }

        if minute < end {
            let previousDay = weekday == 1 ? 7 : weekday - 1
            return schedule.activeWeekdays.contains(previousDay)
        }

        return false
    }

    public func scheduleEndDate(
        _ schedule: ScheduleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let start = schedule.startMinutes
        let end = schedule.endMinutes
        guard start != end else { return nil }

        let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let midnight = calendar.startOfDay(for: now)
        guard let todayEnd = calendar.date(byAdding: .minute, value: end, to: midnight) else {
            return nil
        }

        if start < end || minutesNow < end {
            return todayEnd > now ? todayEnd : calendar.date(byAdding: .day, value: 1, to: todayEnd)
        }
        return calendar.date(byAdding: .day, value: 1, to: todayEnd)
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
}
