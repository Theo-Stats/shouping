import Foundation

public enum DayKey {
    public static func make(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

public final class UsageStore {
    private let fileURL: URL
    private let calendar: Calendar
    private(set) public var daily: DailyUsage

    public init(fileURL: URL, calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(DailyUsage.self, from: data) {
            self.daily = decoded
        } else {
            self.daily = DailyUsage(dayKey: DayKey.make(for: Date(), calendar: calendar))
        }
    }

    @discardableResult
    public func rollDayIfNeeded(now: Date = Date()) -> Bool {
        let expected = DayKey.make(for: now, calendar: calendar)
        guard daily.dayKey != expected else { return false }
        daily = DailyUsage(dayKey: expected)
        persist()
        return true
    }

    public func add(seconds: TimeInterval, to application: AppDescriptor, now: Date = Date()) {
        guard seconds > 0 else { return }
        rollDayIfNeeded(now: now)

        var entry = daily.applications[application.bundleIdentifier]
            ?? UsageEntry(
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                activeSeconds: 0
            )
        entry.displayName = application.displayName
        entry.activeSeconds += seconds
        daily.applications[application.bundleIdentifier] = entry
    }

    public func replace(_ usage: DailyUsage) {
        daily = usage
        persist()
    }

    public func clear() {
        daily = DailyUsage(dayKey: DayKey.make(for: Date(), calendar: calendar))
        persist()
    }

    public func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(daily)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Shouping usage persistence error: %@", error.localizedDescription)
        }
    }
}
