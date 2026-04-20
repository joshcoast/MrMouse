import SwiftUI

struct MenuView: View {
    @EnvironmentObject var mouse: MouseManager

    var body: some View {
        // Status row
        statusRow

        Divider()

        // Toggle
        Button {
            mouse.toggle()
        } label: {
            HStack {
                Image(systemName: mouse.isRunning ? "stop.fill" : "play.fill")
                Text(mouse.isRunning ? "Stop MrMouse" : "Start MrMouse")
            }
        }
        .keyboardShortcut("j", modifiers: [])

        Divider()

        // Wild mode toggle
        Button {
            mouse.toggleWildMode()
        } label: {
            HStack {
                Text("Wild Wiggle")
                if mouse.wildMode {
                    Image(systemName: "checkmark")
                }
            }
        }

        // Only-when-idle toggle
        Button {
            mouse.toggleIdleOnly()
        } label: {
            HStack {
                Text("Only when idle")
                if mouse.idleOnly {
                    Image(systemName: "checkmark")
                }
            }
        }

        Divider()

        // Interval submenu
        Menu("Interval: \(mouse.selectedInterval.label)") {
            ForEach(mouse.intervals) { option in
                Button {
                    mouse.setInterval(option)
                } label: {
                    HStack {
                        Text(option.label)
                        if mouse.selectedInterval == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        // Idle-threshold submenu — only relevant when idle-gating is on.
        if mouse.idleOnly {
            Menu("Start after: \(mouse.idleThreshold.label)") {
                ForEach(mouse.idleThresholds) { option in
                    Button {
                        mouse.setIdleThreshold(option)
                    } label: {
                        HStack {
                            Text(option.label)
                            if mouse.idleThreshold == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        Divider()

        Button("Quit MrMouse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [])
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 6) {
            // Native NSMenu strips custom SwiftUI shapes, so we use an
            // SF Symbol. Color is also stripped, so we vary the *glyph*
            // across the three states instead.
            Image(systemName: statusSymbol)
            Text(statusText)
        }
    }

    /// `circle` (hollow) = off, `circle.dashed` = waiting, `circle.fill` = jiggling.
    private var statusSymbol: String {
        if !mouse.isRunning { return "circle" }
        if mouse.isWaiting  { return "circle.dashed" }
        return "circle.fill"
    }

    private var statusText: String {
        if !mouse.isRunning {
            return "Inactive — mouse is resting"
        }
        if mouse.isWaiting {
            return "Waiting — starts after \(mouse.idleThreshold.label) of idle"
        }
        return mouse.wildMode
            ? "Wiggling wildly every \(mouse.selectedInterval.label)"
            : "Moving every \(mouse.selectedInterval.label)"
    }
}
