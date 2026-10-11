import Foundation

public enum AwakeMode: String, CaseIterable, Sendable {
    case system, display
}

@MainActor
public protocol AssertionBackend {
    func create(_ mode: AwakeMode) throws -> UInt32
    func release(_ id: UInt32) throws
}

/// Owns only IDs created by this controller. Explicit unified Off delegates safe
/// standalone CLI signaling to a separate process backend; Quit remains app-only.
@MainActor
public final class AwakeController {
    private let backend: any AssertionBackend
    private let preferences: AwakePreferences?
    public let session: AwakeSession?
    public let cliClock: CLIActivityClock
    public let timers: AwakeTimers
    public private(set) var assertions: [AwakeMode: UInt32] = [:]
    public var isActive: Bool { !assertions.isEmpty }
    public private(set) var externalCaffeinate: [SleepAssertion] = []
    public var isSessionActive: Bool { isActive || !externalCaffeinate.isEmpty }
    public func isEnabled(_ mode: AwakeMode) -> Bool { assertions[mode] != nil }

    public init(backend: any AssertionBackend, preferences: AwakePreferences? = nil, session: AwakeSession? = nil, cliClock: CLIActivityClock = CLIActivityClock(), timers: AwakeTimers = AwakeTimers()) {
        self.backend = backend
        self.preferences = preferences
        self.session = session
        self.cliClock = cliClock
        self.timers = timers
    }

    public func restorePreferences() throws {
        var firstError: (any Error)?
        for mode in AwakeMode.allCases where preferences?.isEnabled(mode) == true {
            do { try set(mode, enabled: true, persist: false) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }

    public func set(_ mode: AwakeMode, enabled: Bool, persist: Bool = true) throws {
        defer { session?.update(active: isSessionActive) }
        if enabled {
            if assertions[mode] == nil { assertions[mode] = try backend.create(mode) }
        } else {
            if let id = assertions[mode] {
                try backend.release(id)
                assertions[mode] = nil
            }
            timers.cancel(mode)
        }
        if persist { preferences?.set(mode, enabled: enabled) }
    }

    /// Turns a mode on and releases it after `seconds`. A timed run is temporary, so the
    /// saved choice is left alone and a relaunch never restores it.
    public func set(_ mode: AwakeMode, for seconds: TimeInterval) throws {
        guard AwakeTimers.isValid(seconds) else { throw AwakeTimerError.invalidDuration }
        try set(mode, enabled: true, persist: false)
        timers.start(mode, after: seconds)
    }

    /// Releases every mode whose timer has run out. A failed release keeps its timer and is retried.
    public func expireTimers() throws {
        var firstError: (any Error)?
        for mode in timers.expiredModes() {
            do { try set(mode, enabled: false) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }

    public func observeExternalAssertions(_ entries: [SleepAssertion], onACPower: Bool = true) {
        externalCaffeinate = entries.filter {
            $0.isCaffeinate && ($0.keepsSystemAwake || $0.keepsDisplayAwake)
                && ($0.type != "PreventSystemSleep" || onACPower)
        }
        let continuing = cliClock.observe(externalCaffeinate)
        if !isActive && continuing == false {
            session?.update(active: false, creditBeforeStopping: false)
        }
        // A disappearing/unknown CLI assertion must not earn an award during the
        // unobserved interval since the last successful poll.
        session?.update(active: isSessionActive, creditBeforeStopping: isActive)
        if let elapsed = cliClock.elapsed {
            session?.includeCLIInterval(elapsed: elapsed)
        }
    }

    public func turnOff(persist: Bool = true) throws {
        var firstError: (any Error)?
        for mode in AwakeMode.allCases {
            do { try set(mode, enabled: false, persist: persist) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }
}
