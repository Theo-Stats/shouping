import Foundation
import XCTest
@testable import ShoupingCore

final class UsageStoreTests: XCTestCase {
    func testUsagePersistsAndRollsToNewDay() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("usage.json")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let store = UsageStore(fileURL: url, calendar: calendar)
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 11,
            day: 20,
            hour: 12
        )))
        let descriptor = AppDescriptor(
            bundleIdentifier: "com.example.browser",
            displayName: "Browser"
        )

        store.add(seconds: 120, to: descriptor, now: firstDay)
        XCTAssertEqual(store.daily.applications[descriptor.bundleIdentifier]?.activeSeconds, 120)

        let reloaded = UsageStore(fileURL: url, calendar: calendar)
        XCTAssertEqual(reloaded.daily.applications[descriptor.bundleIdentifier]?.activeSeconds, 120)

        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        XCTAssertTrue(reloaded.rollDayIfNeeded(now: nextDay))
        XCTAssertTrue(reloaded.daily.applications.isEmpty)
    }
}
