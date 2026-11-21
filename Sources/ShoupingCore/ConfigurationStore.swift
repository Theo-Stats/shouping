import Foundation

public final class ConfigurationStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> AppConfiguration {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) else {
            return AppConfiguration()
        }
        return decoded
    }

    public func save(_ configuration: AppConfiguration) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Shouping configuration persistence error: %@", error.localizedDescription)
        }
    }
}

public enum AppSupportPaths {
    public static var baseDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return support.appendingPathComponent("Shouping", isDirectory: true)
    }

    public static var configurationURL: URL {
        baseDirectory.appendingPathComponent("configuration.json")
    }

    public static var usageURL: URL {
        baseDirectory.appendingPathComponent("usage.json")
    }

    public static var holidayCalendarURL: URL {
        baseDirectory.appendingPathComponent("china-holidays.json")
    }
}
