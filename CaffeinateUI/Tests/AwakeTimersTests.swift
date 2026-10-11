import Foundation
import Testing
@testable import CaffeinateUICore

@MainActor
private final class TimerBackend: AssertionBackend {
    var next: UInt32 = 200
    var owned: Set<UInt32> = []
    var failRelease = false
    enum Failure: Error { case simulated }
    func create(_ mode: AwakeMode) throws -> UInt32 { next += 1; owned.insert(next); return next }
    func release(_ id: UInt32) throws {
        if failRelease { throw Failure.simulated }
        owned.remove(id)
    }
}

@MainActor private final class Clock { var time: TimeInterval = 1000 }

@MainActor private func makeController(_ clock: Clock, backend: TimerBackend = TimerBackend(),
                                       preferences: AwakePreferences? = nil) -> AwakeController {
    AwakeController(backend: backend, preferences: preferences, timers: AwakeTimers(now: { clock.time }))
}

@MainActor @Test func timerCountsDownAndExpiresExactlyAtDeadline() {
    let clock = Clock()
    let timers = AwakeTimers(now: { clock.time })
    #expect(timers.remaining(.system) == nil)
    #expect(timers.start(.system, after: 60))
    #expect(timers.remaining(.system) == 60)
    clock.time += 59.5
    #expect(timers.remaining(.system) == 0.5)
    #expect(timers.expiredModes().isEmpty)
    clock.time += 0.5
    #expect(timers.expiredModes() == [.system])
    #expect(timers.remaining(.display) == nil)
}

@MainActor @Test func invalidDurationsAreRejectedAndLimitsAreInclusive() {
    let timers = AwakeTimers(now: { 0 })
    for bad in [0, -1, .nan, .infinity, AwakeTimers.maximumSeconds + 1] as [TimeInterval] {
        #expect(!timers.start(.system, after: bad))
    }
    #expect(timers.remaining(.system) == nil)
    #expect(timers.start(.system, after: 1))
    #expect(timers.start(.display, after: AwakeTimers.maximumSeconds))
}

@MainActor @Test func minutesParseStrictlyAndLabelsRoundUp() {
    #expect(AwakeTimers.parseMinutes("30") == 1800)
    #expect(AwakeTimers.parseMinutes(" 5 ") == 300)
    #expect(AwakeTimers.parseMinutes("1440") == 86400)
    for bad in ["", "0", "1441", "abc", "1.5", "-5", "+5", "٣"] { #expect(AwakeTimers.parseMinutes(bad) == nil) }
    #expect(AwakeTimers.label(seconds: 0) == "0 s")
    #expect(AwakeTimers.label(seconds: 45) == "45 s")
    #expect(AwakeTimers.label(seconds: 60) == "1 m")
    #expect(AwakeTimers.label(seconds: 899.5) == "15 m")
    #expect(AwakeTimers.label(seconds: 3600) == "1 h 00 m")
    #expect(AwakeTimers.label(seconds: 3900) == "1 h 05 m")
}

@MainActor @Test func timedRunReleasesOnlyItsModeAtExpiry() throws {
    let clock = Clock(), backend = TimerBackend()
    let controller = makeController(clock, backend: backend)
    try controller.set(.system, for: 60)
    try controller.set(.display, enabled: true)
    clock.time += 59
    try controller.expireTimers()
    #expect(controller.isEnabled(.system))
    clock.time += 1
    try controller.expireTimers()
    #expect(!controller.isEnabled(.system))
    #expect(controller.isEnabled(.display))
    #expect(controller.timers.remaining(.system) == nil)
    #expect(backend.owned.count == 1)
}

@MainActor @Test func manualOffAndTurnOffCancelTimersSoLaterRunsAreNotCut() throws {
    let clock = Clock()
    let controller = makeController(clock)
    try controller.set(.system, for: 300)
    try controller.set(.system, enabled: false)
    #expect(controller.timers.remaining(.system) == nil)
    try controller.set(.system, for: 300)
    try controller.set(.display, for: 300)
    try controller.turnOff()
    #expect(controller.timers.remaining(.system) == nil && controller.timers.remaining(.display) == nil)
    clock.time += 10_000
    try controller.set(.system, enabled: true)
    try controller.expireTimers()
    #expect(controller.isEnabled(.system))
}

@MainActor @Test func failedReleaseKeepsExpiredTimerAndRetries() throws {
    let clock = Clock(), backend = TimerBackend()
    let controller = makeController(clock, backend: backend)
    try controller.set(.system, for: 60)
    clock.time += 60
    backend.failRelease = true
    #expect(throws: TimerBackend.Failure.self) { try controller.expireTimers() }
    #expect(controller.isEnabled(.system))
    #expect(controller.timers.remaining(.system) == 0)
    backend.failRelease = false
    try controller.expireTimers()
    #expect(!controller.isEnabled(.system))
}

@MainActor @Test func timedStartLeavesSavedChoiceAndExpiryClearsIt() throws {
    let suite = "AwakeTimersTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let clock = Clock()
    let controller = makeController(clock, preferences: AwakePreferences(defaults: defaults))
    let preferences = AwakePreferences(defaults: defaults)
    try controller.set(.display, for: 60)
    #expect(!preferences.isEnabled(.display))
    try controller.set(.system, enabled: true)
    try controller.set(.system, for: 60)
    #expect(preferences.isEnabled(.system))
    clock.time += 60
    try controller.expireTimers()
    #expect(!preferences.isEnabled(.system) && !preferences.isEnabled(.display))
}

@MainActor @Test func invalidTimedStartThrowsWithoutTurningOn() {
    let controller = makeController(Clock())
    #expect(throws: AwakeTimerError.self) { try controller.set(.system, for: 0) }
    #expect(throws: AwakeTimerError.self) { try controller.set(.display, for: AwakeTimers.maximumSeconds + 1) }
    #expect(!controller.isActive)
}
