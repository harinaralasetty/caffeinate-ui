import Foundation

public enum AwakeTimerError: LocalizedError, Equatable {
    case invalidDuration
    public var errorDescription: String? { "Choose a timer between 1 minute and 24 hours." }
}

/// Optional auto-off deadlines for the app's own assertions. Deadlines are never
/// persisted: a relaunch restores choices but not an old countdown.
@MainActor
public final class AwakeTimers {
    public static let maximumSeconds: TimeInterval = 24 * 3600
    private let now: () -> TimeInterval
    private var deadlines: [AwakeMode: TimeInterval] = [:]

    /// The default clock keeps counting through system sleep, so a timer measures real elapsed time.
    public init(now: (() -> TimeInterval)? = nil) {
        let reference = ContinuousClock.now
        self.now = now ?? {
            let elapsed = reference.duration(to: ContinuousClock.now).components
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
    }

    public static func isValid(_ seconds: TimeInterval) -> Bool {
        seconds.isFinite && seconds > 0 && seconds <= maximumSeconds
    }

    @discardableResult
    public func start(_ mode: AwakeMode, after seconds: TimeInterval) -> Bool {
        guard Self.isValid(seconds) else { return false }
        deadlines[mode] = now() + seconds
        return true
    }

    public func cancel(_ mode: AwakeMode) { deadlines[mode] = nil }

    public func remaining(_ mode: AwakeMode) -> TimeInterval? {
        deadlines[mode].map { max(0, $0 - now()) }
    }

    /// Modes whose deadline has passed. Cleared only when the mode is turned off.
    public func expiredModes() -> [AwakeMode] {
        let time = now()
        return AwakeMode.allCases.filter { (deadlines[$0] ?? .infinity) <= time }
    }

    /// Whole minutes from "1" to "1440"; anything else is rejected.
    public static func parseMinutes(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isASCII), trimmed.allSatisfy(\.isNumber),
              let minutes = Int(trimmed) else { return nil }
        let seconds = TimeInterval(minutes) * 60
        return isValid(seconds) ? seconds : nil
    }

    /// Rounds up so a fresh 15-minute timer reads "15 m", not "14 m".
    public static func label(seconds: TimeInterval) -> String {
        let total = Int(max(0, min(seconds, 1e9)).rounded(.up))
        let minutes = (total + 59) / 60
        if minutes >= 60 { return "\(minutes / 60) h " + String(format: "%02d", minutes % 60) + " m" }
        return total >= 60 ? "\(minutes) m" : "\(total) s"
    }
}
