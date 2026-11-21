import Foundation

public struct ContinuousUseReminderTracker: Sendable {
    public private(set) var continuousSeconds: TimeInterval
    public private(set) var isPromptPending: Bool

    public init(continuousSeconds: TimeInterval = 0, isPromptPending: Bool = false) {
        self.continuousSeconds = continuousSeconds
        self.isPromptPending = isPromptPending
    }

    @discardableResult
    public mutating func update(
        settings: CycleSettings,
        isLimitedUse: Bool,
        isUserActive: Bool,
        elapsed: TimeInterval
    ) -> Bool {
        guard settings.reminderEnabled else {
            reset()
            return false
        }
        guard !isPromptPending else { return false }
        guard isLimitedUse, isUserActive, elapsed > 0 else {
            continuousSeconds = 0
            return false
        }

        continuousSeconds += elapsed
        if continuousSeconds >= TimeInterval(max(settings.reminderMinutes, 1) * 60) {
            isPromptPending = true
            return true
        }
        return false
    }

    public mutating func resolvePrompt(resetTimer: Bool = true) {
        isPromptPending = false
        if resetTimer {
            continuousSeconds = 0
        }
    }

    public mutating func reset() {
        continuousSeconds = 0
        isPromptPending = false
    }
}
