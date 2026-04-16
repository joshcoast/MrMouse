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

/// Observable controller that owns the timer and drives mouse movement.
final class MouseManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isRunning = false
    @Published var selectedInterval: MoveInterval
    @Published var wildMode: Bool = false

    // MARK: - Constants

    let intervals: [MoveInterval] = [
        MoveInterval(label: "15 seconds", seconds: 15),
        MoveInterval(label: "30 seconds", seconds: 30),
        MoveInterval(label: "1 minute",   seconds: 60),
        MoveInterval(label: "2 minutes",  seconds: 120),
        MoveInterval(label: "5 minutes",  seconds: 300),
        MoveInterval(label: "10 minutes", seconds: 600),
    ]

    // MARK: - Private

    private var timer: Timer?
    private var direction: CGFloat = 1
    private var sleepAssertion: IOPMAssertionID = 0

    private static let defaultIntervalKey = "selectedIntervalSeconds"
    private static let wildModeKey = "wildMode"

    // MARK: - Init / deinit

    init() {
        // Restore persisted interval (default: 1 minute).
        let saved = UserDefaults.standard.double(forKey: Self.defaultIntervalKey)
        let match = [
            MoveInterval(label: "15 seconds", seconds: 15),
            MoveInterval(label: "30 seconds", seconds: 30),
            MoveInterval(label: "1 minute",   seconds: 60),
            MoveInterval(label: "2 minutes",  seconds: 120),
            MoveInterval(label: "5 minutes",  seconds: 300),
            MoveInterval(label: "10 minutes", seconds: 600),
        ].first { $0.seconds == saved }
        selectedInterval = match ?? MoveInterval(label: "1 minute", seconds: 60)
        wildMode = UserDefaults.standard.bool(forKey: Self.wildModeKey)
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
