import Foundation
import CoreGraphics
import IOKit.pwr_mgt
import Combine

/// Interval options for the jiggle timer.
struct JiggleInterval: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let seconds: TimeInterval
}

/// Observable controller that owns the timer and drives mouse movement.
final class JigglerManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isRunning = false
    @Published var selectedInterval: JiggleInterval

    // MARK: - Constants

    let intervals: [JiggleInterval] = [
        JiggleInterval(label: "15 seconds", seconds: 15),
        JiggleInterval(label: "30 seconds", seconds: 30),
        JiggleInterval(label: "1 minute",   seconds: 60),
        JiggleInterval(label: "2 minutes",  seconds: 120),
        JiggleInterval(label: "5 minutes",  seconds: 300),
        JiggleInterval(label: "10 minutes", seconds: 600),
    ]

    // MARK: - Private

    private var timer: Timer?
    private var direction: CGFloat = 1
    private var sleepAssertion: IOPMAssertionID = 0

    private static let defaultIntervalKey = "selectedIntervalSeconds"

    // MARK: - Init / deinit

    init() {
        // Restore persisted interval (default: 1 minute).
        let saved = UserDefaults.standard.double(forKey: Self.defaultIntervalKey)
        let match = [
            JiggleInterval(label: "15 seconds", seconds: 15),
            JiggleInterval(label: "30 seconds", seconds: 30),
            JiggleInterval(label: "1 minute",   seconds: 60),
            JiggleInterval(label: "2 minutes",  seconds: 120),
            JiggleInterval(label: "5 minutes",  seconds: 300),
            JiggleInterval(label: "10 minutes", seconds: 600),
        ].first { $0.seconds == saved }
        selectedInterval = match ?? JiggleInterval(label: "1 minute", seconds: 60)
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    func toggle() {
        isRunning ? stop() : start()
    }

    func setInterval(_ interval: JiggleInterval) {
        selectedInterval = interval
        UserDefaults.standard.set(interval.seconds, forKey: Self.defaultIntervalKey)
        if isRunning {
            restartTimer()
        }
    }

    // MARK: - Private helpers

    private func start() {
        isRunning = true
        acquireSleepAssertion()
        scheduleTimer()
    }

    private func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        releaseSleepAssertion()
    }

    private func restartTimer() {
        timer?.invalidate()
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: selectedInterval.seconds,
            repeats: true
        ) { [weak self] _ in
            self?.jiggle()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: - Mouse movement

    private func jiggle() {
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

    // MARK: - Power management

    private func acquireSleepAssertion() {
        let reason = "Mouse Jiggler is keeping the display awake" as CFString
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
