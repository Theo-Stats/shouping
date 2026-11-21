import Foundation
import ShoupingCore

struct HolidayCalendarRefreshResult: Sendable {
    let calendar: ChineseHolidayCalendar
    let loadedYears: [Int]
    let failedYears: [Int]
}

struct HolidayCalendarService {
    func refresh(
        existing: ChineseHolidayCalendar,
        now: Date = Date(),
        calendar systemCalendar: Calendar = .current
    ) async -> HolidayCalendarRefreshResult {
        var result = existing
        let currentYear = systemCalendar.component(.year, from: now)
        var loadedYears: [Int] = []
        var failedYears: [Int] = []

        for year in [currentYear, currentYear + 1] {
            do {
                let asset = try await fetch(year: year)
                result.merge(asset, now: now)
                loadedYears.append(year)
            } catch {
                failedYears.append(year)
            }
        }

        return HolidayCalendarRefreshResult(
            calendar: result,
            loadedYears: loadedYears,
            failedYears: failedYears
        )
    }

    private func fetch(year: Int) async throws -> ChineseHolidayAsset {
        let urls = [
            URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!,
            URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!,
        ]

        var lastError: Error?
        for url in urls {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadRevalidatingCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return try JSONDecoder().decode(ChineseHolidayAsset.self, from: data)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}
