import Foundation

public struct CycleTracker: Sendable {
    public private(set) var continuousSeconds: TimeInterval
    public private(set) var restEnd: Date?

    public init(continuousSeconds: TimeInterval = 0, restEnd: Date? = nil) {
        self.continuousSeconds = continuousSeconds
        self.restEnd = restEnd
    }

    public mutating func update(
        settings: CycleSettings,
        isLimitedUse: Bool,
        isUserActive: Bool,
        elapsed: TimeInterval,
        now: Date
    ) {
        guard settings.isEnabled else {
            continuousSeconds = 0
            restEnd = nil
            return
        }

        if let restEnd {
            if now >= restEnd {
                self.restEnd = nil
                continuousSeconds = 0
            }
            return
        }

        guard isLimitedUse, isUserActive, elapsed > 0 else {
            continuousSeconds = 0
            return
        }

        continuousSeconds += elapsed
        if continuousSeconds >= TimeInterval(max(settings.useMinutes, 1) * 60) {
            restEnd = now.addingTimeInterval(TimeInterval(max(settings.restMinutes, 1) * 60))
        }
    }
}
