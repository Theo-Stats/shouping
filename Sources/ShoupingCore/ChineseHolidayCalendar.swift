import Foundation

public struct ChineseHolidayAsset: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        public let name: String
        public let date: String
        public let isOffDay: Bool

        public init(name: String, date: String, isOffDay: Bool) {
            self.name = name
            self.date = date
            self.isOffDay = isOffDay
        }
    }

    public let year: Int
    public let papers: [String]
    public let days: [Day]

    public init(year: Int, papers: [String], days: [Day]) {
        self.year = year
        self.papers = papers
        self.days = days
    }
}

public struct ChineseHolidayCalendar: Codable, Equatable, Sendable {
    public private(set) var overrides: [String: Bool]
    public private(set) var loadedYears: Set<Int>
    public private(set) var updatedAt: Date?

    public init(
        overrides: [String: Bool] = [:],
        loadedYears: Set<Int> = [],
        updatedAt: Date? = nil
    ) {
        self.overrides = overrides
        self.loadedYears = loadedYears
        self.updatedAt = updatedAt
    }

    public mutating func merge(_ asset: ChineseHolidayAsset, now: Date = Date()) {
        for day in asset.days {
            overrides[day.date] = day.isOffDay
        }
        loadedYears.insert(asset.year)
        updatedAt = now
    }

    public func hasLoadedYear(containing date: Date, calendar: Calendar = .current) -> Bool {
        loadedYears.contains(calendar.component(.year, from: date))
    }

    public func isWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        if let override = overrides[Self.key(for: date, calendar: calendar)] {
            return !override
        }
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }

    public func isNonWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        !isWorkday(date, calendar: calendar)
    }

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

public enum HolidayCalendarCache {
    public static func load(from url: URL) -> ChineseHolidayCalendar {
        guard let data = try? Data(contentsOf: url),
              let calendar = try? JSONDecoder().decode(ChineseHolidayCalendar.self, from: data) else {
            return ChineseHolidayCalendar()
        }
        return calendar
    }

    public static func save(_ calendar: ChineseHolidayCalendar, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(calendar).write(to: url, options: .atomic)
    }
}
