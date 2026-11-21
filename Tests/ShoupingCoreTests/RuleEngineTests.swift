import XCTest
@testable import ShoupingCore

final class RuleEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar
    }

    func testNormalScheduleActivatesOnSelectedWeekday() throws {
        let engine = RuleEngine()
        let configuration = AppConfiguration(
            schedule: ScheduleSettings(
                isEnabled: true,
                activeWeekdays: [2],
                startMinutes: 9 * 60,
                endMinutes: 11 * 60
            )
        )
        let mondayAtTen = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 23,
            hour: 10,
            minute: 0
        )))

        XCTAssertTrue(engine.scheduleIsActive(configuration.schedule, now: mondayAtTen, calendar: calendar))
    }

    func testCrossMidnightScheduleAfterMidnightUsesPreviousWeekday() throws {
        let engine = RuleEngine()
        let schedule = ScheduleSettings(
            isEnabled: true,
            activeWeekdays: [2],
            startMinutes: 23 * 60,
            endMinutes: 7 * 60
        )
        let tuesdayAtSix = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 24,
            hour: 6,
            minute: 0
        )))

        XCTAssertTrue(engine.scheduleIsActive(schedule, now: tuesdayAtSix, calendar: calendar))
    }

    func testSchedulePreLockProtectsSystemManagementApplications() throws {
        let engine = RuleEngine()
        let schedule = ScheduleSettings(
            isEnabled: true,
            activeWeekdays: [2],
            startMinutes: 17 * 60,
            endMinutes: 18 * 60,
            protectionLeadMinutes: 15
        )
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 23,
            hour: 16,
            minute: 50
        )))
        let configuration = AppConfiguration(schedule: schedule)
        let restriction = engine.activeRestriction(
            configuration: configuration,
            usage: DailyUsage(dayKey: "2026-11-23"),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(restriction?.reason, .preLockGuard)
        XCTAssertTrue(restriction?.blockedBundleIdentifiers.contains("com.apple.finder") == true)
        XCTAssertEqual(
            restriction?.endDate,
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 17))
        )
    }

    func testSchedulePreLockDoesNotStartBeforeLeadWindow() throws {
        let engine = RuleEngine()
        let schedule = ScheduleSettings(
            isEnabled: true,
            activeWeekdays: [2],
            startMinutes: 17 * 60,
            endMinutes: 18 * 60,
            protectionLeadMinutes: 15
        )
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 23,
            hour: 16,
            minute: 40
        )))

        XCTAssertNil(
            engine.activeRestriction(
                configuration: AppConfiguration(schedule: schedule),
                usage: DailyUsage(dayKey: "2026-11-23"),
                now: now,
                calendar: calendar
            )
        )
    }

    func testMultipleCustomWeekdaySchemesKeepIndependentTimes() throws {
        let engine = RuleEngine()
        let rules = [
            ScheduleRule(
                name: "周一和周二",
                customWeekdays: [2, 3],
                startMinutes: 9 * 60,
                endMinutes: 10 * 60,
                protectionLeadMinutes: 15
            ),
            ScheduleRule(
                name: "周三和周四",
                customWeekdays: [4, 5],
                startMinutes: 14 * 60,
                endMinutes: 15 * 60,
                protectionLeadMinutes: 15
            ),
        ]
        let configuration = AppConfiguration(schedules: rules)
        let wednesdayAfternoon = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 25,
            hour: 14,
            minute: 30
        )))
        let mondayAfternoon = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 23,
            hour: 14,
            minute: 30
        )))

        XCTAssertEqual(
            engine.activeRestriction(
                configuration: configuration,
                usage: DailyUsage(dayKey: "2026-11-25"),
                now: wednesdayAfternoon,
                calendar: calendar
            )?.reason,
            .schedule
        )
        XCTAssertNil(
            engine.activeRestriction(
                configuration: configuration,
                usage: DailyUsage(dayKey: "2026-11-23"),
                now: mondayAfternoon,
                calendar: calendar
            )
        )
    }

    func testWorkdayModeUsesMakeupWorkdayOverride() throws {
        let engine = RuleEngine()
        let rule = ScheduleRule(
            name: "工作日",
            dayMode: .workdays,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60
        )
        let configuration = AppConfiguration(schedules: [rule])
        let saturdayMakeupDay = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 14,
            hour: 9,
            minute: 30
        )))
        let holidays = ChineseHolidayCalendar(
            overrides: ["2026-02-14": false],
            loadedYears: [2026]
        )

        XCTAssertEqual(
            engine.activeRestriction(
                configuration: configuration,
                usage: DailyUsage(dayKey: "2026-02-14"),
                now: saturdayMakeupDay,
                calendar: calendar,
                holidayCalendar: holidays
            )?.reason,
            .schedule
        )
    }

    func testNonWorkdayModeUsesHolidayOverride() throws {
        let engine = RuleEngine()
        let rule = ScheduleRule(
            name: "非工作日",
            dayMode: .nonWorkdays,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60
        )
        let configuration = AppConfiguration(schedules: [rule])
        let sundayHoliday = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 15,
            hour: 9,
            minute: 30
        )))
        let holidays = ChineseHolidayCalendar(
            overrides: ["2026-02-15": true],
            loadedYears: [2026]
        )

        XCTAssertEqual(
            engine.activeRestriction(
                configuration: configuration,
                usage: DailyUsage(dayKey: "2026-02-15"),
                now: sundayHoliday,
                calendar: calendar,
                holidayCalendar: holidays
            )?.reason,
            .schedule
        )
    }

    func testTemporaryUnlockSuppressesAllRestrictions() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let engine = RuleEngine()
        var configuration = AppConfiguration()
        configuration.focusEndUnixTime = now.addingTimeInterval(1_800).timeIntervalSince1970
        configuration.temporaryUnlockEndUnixTime = now.addingTimeInterval(300).timeIntervalSince1970

        let result = engine.activeRestriction(
            configuration: configuration,
            usage: DailyUsage(dayKey: "2027-01-15"),
            now: now,
            calendar: calendar
        )

        XCTAssertNil(result)
    }

    func testSkippedRestrictionAlsoSuppressesBackgroundRecovery() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let engine = RuleEngine()
        var configuration = AppConfiguration()
        configuration.focusEndUnixTime = now.addingTimeInterval(1_800).timeIntervalSince1970
        configuration.skippedRestrictionEndUnixTime = now.addingTimeInterval(900).timeIntervalSince1970

        let result = engine.activeRestriction(
            configuration: configuration,
            usage: DailyUsage(dayKey: "2027-01-15"),
            now: now,
            calendar: calendar,
            honorTemporaryUnlock: false
        )

        XCTAssertNil(result)
    }

    func testDailyLimitBlocksOnlySelectedApplications() {
        let engine = RuleEngine()
        var configuration = AppConfiguration()
        configuration.limit = LimitSettings(isEnabled: true, dailyMinutes: 30)
        configuration.limitedApplications = [
            AppDescriptor(bundleIdentifier: "com.example.video", displayName: "Video")
        ]
        var usage = DailyUsage(dayKey: "2026-11-20")
        usage.applications["com.example.video"] = UsageEntry(
            bundleIdentifier: "com.example.video",
            displayName: "Video",
            activeSeconds: 1_800
        )

        let restriction = engine.activeRestriction(
            configuration: configuration,
            usage: usage,
            now: Date(),
            calendar: calendar
        )

        XCTAssertEqual(restriction?.reason, .dailyLimit)
        XCTAssertTrue(
            engine.shouldBlockApplication(
                bundleIdentifier: "com.example.video",
                restriction: restriction!,
                allowedBundleIdentifiers: []
            )
        )
        XCTAssertFalse(
            engine.shouldBlockApplication(
                bundleIdentifier: "com.example.editor",
                restriction: restriction!,
                allowedBundleIdentifiers: []
            )
        )
    }

    func testEmergencyShortcutRequiresControlCommandAndU() {
        XCTAssertTrue(EmergencyShortcut.matches(control: true, command: true, keyCode: 32))
        XCTAssertFalse(EmergencyShortcut.matches(control: false, command: true, keyCode: 32))
        XCTAssertFalse(EmergencyShortcut.matches(control: true, command: false, keyCode: 32))
        XCTAssertFalse(EmergencyShortcut.matches(control: true, command: true, keyCode: 31))
    }

    func testOlderFocusConfigurationDefaultsToPauseAndSkipAllowed() throws {
        let data = Data("""
        {
          "strength": "strict",
          "enforceKeyboardLock": true,
          "defaultFocusMinutes": 40
        }
        """.utf8)
        let settings = try JSONDecoder().decode(FocusSettings.self, from: data)

        XCTAssertTrue(settings.controls.allowPause)
        XCTAssertTrue(settings.controls.allowSkip)
    }

    func testOlderConfigurationDefaultsToFocusShieldWithoutWeather() throws {
        let data = Data("""
        {
          "focus": {
            "strength": "shield",
            "enforceKeyboardLock": false,
            "defaultFocusMinutes": 25
          },
          "schedule": {
            "isEnabled": false,
            "activeWeekdays": [2, 3, 4, 5, 6],
            "startMinutes": 540,
            "endMinutes": 690
          },
          "limit": {
            "isEnabled": false,
            "dailyMinutes": 60
          }
        }
        """.utf8)
        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)

        XCTAssertFalse(configuration.appearance.weatherEnabled)
        XCTAssertEqual(configuration.schedule.protectionLeadMinutes, 15)
        XCTAssertTrue(configuration.hideApplicationInFinder)
        XCTAssertEqual(configuration.schedules.count, 1)
    }

    func testClockAppearanceRoundTrips() throws {
        let appearance = AppearanceSettings(
            weatherEnabled: true,
            weatherCity: "上海"
        )
        let data = try JSONEncoder().encode(appearance)
        let decoded = try JSONDecoder().decode(AppearanceSettings.self, from: data)

        XCTAssertEqual(decoded, appearance)
    }

    func testLegacyAppearanceStyleIsIgnored() throws {
        let data = Data(#"{"style":"flip","weatherEnabled":false}"#.utf8)
        let appearance = try JSONDecoder().decode(AppearanceSettings.self, from: data)

        XCTAssertFalse(appearance.weatherEnabled)
        XCTAssertTrue(appearance.weatherCity.isEmpty)
    }
}
