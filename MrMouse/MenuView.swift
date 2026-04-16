import SwiftUI

struct MenuView: View {
    @EnvironmentObject var mouse: MouseManager

    var body: some View {
        // Status row
        statusRow

        Divider()

        // Toggle
        Button(mouse.isRunning ? "Stop MrMouse" : "Start MrMouse") {
            mouse.toggle()
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
            Circle()
                .fill(mouse.isRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
                .padding(.leading, 2)

            if mouse.isRunning {
                Text(mouse.wildMode
                     ? "Wiggling wildly every \(mouse.selectedInterval.label)"
                     : "Moving every \(mouse.selectedInterval.label)")
                    .font(.callout)
            } else {
                Text("Inactive — mouse is resting")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
