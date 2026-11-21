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
}
