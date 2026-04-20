import Foundation
import CoreGraphics
import IOKit.pwr_mgt
import Combine

/// Interval options for the move timer.
struct MoveInterval: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let seconds: TimeInterval
}

/// How long the user must be idle before jiggling begins (when idle-gating is on).
struct IdleThreshold: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let seconds: TimeInterval
}

/// Observable controller that owns the timer and drives mouse movement.
final class MouseManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isRunning = false
    /// True when `isRunning && idleOnly` and we haven't yet seen enough
    /// idle time to start jiggling. Drives the "Waiting for idle…" label.
    @Published private(set) var isWaiting = false
    @Published var selectedInterval: MoveInterval
    @Published var wildMode: Bool = false
    @Published var idleOnly: Bool = false
    @Published var idleThreshold: IdleThreshold

    // MARK: - Constants

    let intervals: [MoveInterval] = [
        MoveInterval(label: "15 seconds", seconds: 15),
        MoveInterval(label: "30 seconds", seconds: 30),
        MoveInterval(label: "1 minute",   seconds: 60),
        MoveInterval(label: "2 minutes",  seconds: 120),
        MoveInterval(label: "5 minutes",  seconds: 300),
        MoveInterval(label: "10 minutes", seconds: 600),
    ]

    let idleThresholds: [IdleThreshold] = [
        IdleThreshold(label: "1 minute",   seconds: 60),
        IdleThreshold(label: "2 minutes",  seconds: 120),
        IdleThreshold(label: "5 minutes",  seconds: 300),
        IdleThreshold(label: "10 minutes", seconds: 600),
        IdleThreshold(label: "15 minutes", seconds: 900),
    ]

    /// How often to check system idle time while we're waiting for the
    /// user to step away. Fast enough to feel responsive, slow enough not
    /// to matter for power.
    private static let idlePollInterval: TimeInterval = 3

    // MARK: - Private

    private var timer: Timer?
    private var direction: CGFloat = 1
    private var sleepAssertion: IOPMAssertionID = 0

    private static let defaultIntervalKey  = "selectedIntervalSeconds"
    private static let wildModeKey         = "wildMode"
    private static let idleOnlyKey         = "idleOnly"
    private static let idleThresholdKey    = "idleThresholdSeconds"

    // MARK: - Init / deinit

    init() {
        // Restore persisted interval (default: 1 minute).
        let savedInterval = UserDefaults.standard.double(forKey: Self.defaultIntervalKey)
        let intervalMatch = [
            MoveInterval(label: "15 seconds", seconds: 15),
            MoveInterval(label: "30 seconds", seconds: 30),
            MoveInterval(label: "1 minute",   seconds: 60),
            MoveInterval(label: "2 minutes",  seconds: 120),
            MoveInterval(label: "5 minutes",  seconds: 300),
            MoveInterval(label: "10 minutes", seconds: 600),
        ].first { $0.seconds == savedInterval }
        selectedInterval = intervalMatch ?? MoveInterval(label: "1 minute", seconds: 60)

        // Restore persisted idle threshold (default: 5 minutes).
        let savedThreshold = UserDefaults.standard.double(forKey: Self.idleThresholdKey)
        let thresholdMatch = [
            IdleThreshold(label: "1 minute",   seconds: 60),
            IdleThreshold(label: "2 minutes",  seconds: 120),
            IdleThreshold(label: "5 minutes",  seconds: 300),
            IdleThreshold(label: "10 minutes", seconds: 600),
            IdleThreshold(label: "15 minutes", seconds: 900),
        ].first { $0.seconds == savedThreshold }
        idleThreshold = thresholdMatch ?? IdleThreshold(label: "5 minutes", seconds: 300)

        wildMode = UserDefaults.standard.bool(forKey: Self.wildModeKey)
        idleOnly = UserDefaults.standard.bool(forKey: Self.idleOnlyKey)
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    func toggle() {
        isRunning ? stop() : start()
    }

    func setInterval(_ interval: MoveInterval) {
        selectedInterval = interval
        UserDefaults.standard.set(interval.seconds, forKey: Self.defaultIntervalKey)
        if isRunning {
            restartTimer()
        }
    }

    func toggleWildMode() {
        wildMode.toggle()
        UserDefaults.standard.set(wildMode, forKey: Self.wildModeKey)
    }

    func toggleIdleOnly() {
        idleOnly.toggle()
        UserDefaults.standard.set(idleOnly, forKey: Self.idleOnlyKey)
        // Re-arm with the new mode if we're currently running.
        if isRunning {
            stopAllTimers()
            scheduleForCurrentMode()
        }
    }

    func setIdleThreshold(_ threshold: IdleThreshold) {
        idleThreshold = threshold
        UserDefaults.standard.set(threshold.seconds, forKey: Self.idleThresholdKey)
        // If we're currently waiting, keep waiting (new threshold applies
        // on the next poll tick). If actively jiggling, a larger threshold
        // might now mean we should switch back to waiting — next tick handles it.
    }

    // MARK: - Private helpers

    private func start() {
        isRunning = true
        acquireSleepAssertion()
        scheduleForCurrentMode()
    }

    private func stop() {
        isRunning = false
        isWaiting = false
        stopAllTimers()
        releaseSleepAssertion()
    }

    private func restartTimer() {
        stopAllTimers()
        scheduleForCurrentMode()
    }

    private func stopAllTimers() {
        timer?.invalidate()
        timer = nil
    }

    /// Entry point from `start()` and whenever mode-affecting preferences change:
    /// picks the right timer (jiggle or idle-poll) for the current state.
    private func scheduleForCurrentMode() {
        if idleOnly {
            // If the user's already been idle long enough, skip straight
            // to jiggling. Otherwise arm the poll timer.
            if currentIdleSeconds() >= idleThreshold.seconds {
                isWaiting = false
                scheduleJiggleTimer(fireImmediately: true)
            } else {
                isWaiting = true
                scheduleIdlePollTimer()
            }
        } else {
            isWaiting = false
            scheduleJiggleTimer(fireImmediately: false)
        }
    }

    /// Timer that just does a jiggle on every tick. Used directly when
    /// idle-gating is off, and once the idle threshold is crossed.
    private func scheduleJiggleTimer(fireImmediately: Bool) {
        timer = Timer.scheduledTimer(
            withTimeInterval: selectedInterval.seconds,
            repeats: true
        ) { [weak self] _ in
            self?.jiggleTick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        if fireImmediately {
            // Don't wait a whole interval for the first jiggle after the
            // user has just finished being idle long enough.
            jiggleTick()
        }
    }

    /// Timer that polls system idle time while we're waiting for the user
    /// to step away. When the threshold is crossed, swaps itself out for
    /// the jiggle timer.
    private func scheduleIdlePollTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.idlePollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.idlePollTick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Tick body for the jiggle timer. When idle-gating is on, we re-check
    /// idle time so we can demote ourselves back to waiting if the user
    /// has returned.
    private func jiggleTick() {
        if idleOnly && currentIdleSeconds() < idleThreshold.seconds {
            // User is back — go wait again.
            stopAllTimers()
            isWaiting = true
            scheduleIdlePollTimer()
            return
        }
        jiggle()
    }

    private func idlePollTick() {
        guard idleOnly else {
            // Mode changed out from under us — self-heal.
            stopAllTimers()
            scheduleForCurrentMode()
            return
        }
        if currentIdleSeconds() >= idleThreshold.seconds {
            stopAllTimers()
            isWaiting = false
            scheduleJiggleTimer(fireImmediately: true)
        }
    }

    /// System-wide seconds since the last real input (keyboard, mouse, etc.).
    /// `CGWarpMouseCursorPosition` does not reset this counter, which is
    /// exactly why MrMouse can use this to detect the real human's return.
    private func currentIdleSeconds() -> TimeInterval {
        // `CGEventType(rawValue: ~0)` is the idiomatic "any event type" value.
        guard let anyEvent = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyEvent
        )
    }

    // MARK: - Mouse movement

    private func jiggle() {
        wildMode ? wildJiggle() : normalJiggle()
    }

    private func normalJiggle() {
        guard let event = CGEvent(source: nil) else { return }
        let origin = event.location

        // Nudge 1 px in alternating directions, then snap back.
        let nudged = CGPoint(x: origin.x + direction, y: origin.y)
        CGWarpMouseCursorPosition(nudged)
        CGAssociateMouseAndMouseCursorPosition(1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            CGWarpMouseCursorPosition(origin)
            CGAssociateMouseAndMouseCursorPosition(1)
        }

        direction *= -1
    }

    /// Mimics a person randomly shaking their mouse with a burst of erratic moves.
    private func wildJiggle() {
        guard let event = CGEvent(source: nil) else { return }
        let origin = event.location

        let moveCount = Int.random(in: 8...14)
        var elapsed = 0.0

        for _ in 0..<moveCount {
            let delay = elapsed + Double.random(in: 0.03...0.07)
            elapsed = delay
            let dx = CGFloat.random(in: -45...45)
            let dy = CGFloat.random(in: -45...45)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard self != nil else { return }
                CGWarpMouseCursorPosition(CGPoint(x: origin.x + dx, y: origin.y + dy))
                CGAssociateMouseAndMouseCursorPosition(1)
            }
        }

        // Snap back to origin after the burst.
        DispatchQueue.main.asyncAfter(deadline: .now() + elapsed + 0.05) {
            CGWarpMouseCursorPosition(origin)
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    // MARK: - Power management

    private func acquireSleepAssertion() {
        let reason = "MrMouse is keeping the display awake" as CFString
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &sleepAssertion
        )
    }

    private func releaseSleepAssertion() {
        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
    }
}
